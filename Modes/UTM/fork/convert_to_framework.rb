#!/usr/bin/env ruby
# frozen_string_literal: true
#
# convert_to_framework.rb  <path-to-UTM.xcodeproj>
#
# Converts UTM's `iOS-SE` application target *in place* into an embeddable framework
# (UTM.framework, module "UTM"). Runs only against a fresh UTM clone on CI.
#
# Framework name MUST equal the module name (UTM): Clang locates the mixed ObjC+Swift
# module by bundle name. PRODUCT_MODULE_NAME is already "UTM"; we set PRODUCT_NAME=UTM so
# the product is UTM.framework. The app's SWIFT_OBJC_BRIDGING_HEADER is illegal in a
# framework, so it's replaced by the UTM.h umbrella (apply_fork.sh dropped it in) which
# makes UTM's iOS ObjC headers public; CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES
# lets those headers keep their non-modular QEMU/C includes.

require 'xcodeproj'

project_path = ARGV[0] || 'UTM.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'iOS-SE' }
raise "iOS-SE target not found in #{project_path}" unless target

puts "Converting target '#{target.name}' -> UTM.framework ..."

# 1. Flip the app target into a framework.
target.product_type = 'com.apple.product-type.framework'
product_ref = target.product_reference
product_ref.name = 'UTM.framework'
product_ref.path = 'UTM.framework'
product_ref.explicit_file_type = 'wrapper.framework'
product_ref.include_in_index = '0'

# 2. Build settings.
target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = 'UTM'                 # framework name must equal module name
  s['PRODUCT_MODULE_NAME'] = 'UTM'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'ai.openclawfoundation.utmmode'
  s['MACH_O_TYPE'] = 'mh_dylib'
  s['DEFINES_MODULE'] = 'YES'
  s['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'

  # UTM's iOS-SE Release config ships AddressSanitizer on (build intermediates land in
  # Objects-normal-asan; the framework picks up an @rpath/libclang_rt.asan_ios_dynamic.dylib
  # LC_LOAD_DYLIB). The prebuilt sysroot dylibs are NOT asan-instrumented (verified), so asan
  # here is pure overhead — it drags the sanitizer runtime and bloats the binary. Force it off
  # for the embedded release framework.
  s['ENABLE_ADDRESS_SANITIZER'] = 'NO'
  s['CLANG_ADDRESS_SANITIZER'] = 'NO'
  s['SKIP_INSTALL'] = 'NO'
  s['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO'
  s['INFOPLIST_FILE'] = 'UTMMode-Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['ENABLE_BITCODE'] = 'NO'
  s['DYLIB_INSTALL_NAME_BASE'] = '@rpath'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']

  # The framework's own ObjC files import the module's INTERNAL Swift interface via the
  # quoted "UTM-Swift.h" (the public <UTM/UTM-Swift.h> exposes only public @objc, but UTM's
  # ObjC needs internal @objc). Ensure the generated internal header dir is searched.
  hsp = s['HEADER_SEARCH_PATHS']
  hsp = hsp.is_a?(Array) ? hsp.dup : (hsp ? [hsp] : ['$(inherited)'])
  ['$(DERIVED_SOURCES_DIR)', '$(DERIVED_FILE_DIR)'].each { |p| hsp << p unless hsp.include?(p) }
  s['HEADER_SEARCH_PATHS'] = hsp

  # Frameworks can't use a bridging header — the umbrella replaces it.
  s.delete('SWIFT_OBJC_BRIDGING_HEADER')

  # Code-signed by the embedding app, not here.
  s['CODE_SIGNING_ALLOWED'] = 'NO'
  s['CODE_SIGNING_REQUIRED'] = 'NO'
  s['CODE_SIGN_IDENTITY'] = ''
  s['CODE_SIGN_ENTITLEMENTS'] = ''
  s.delete('CODE_SIGN_STYLE')
  s.delete('DEVELOPMENT_TEAM')
  s.delete('PROVISIONING_PROFILE_SPECIFIER')
end

# 3. Umbrella + the iOS ObjC headers the (old) bridging header exposed -> Public.
headers_phase = target.headers_build_phase

def make_public(project, headers_phase, name)
  ref = project.files.find { |f| f.path && File.basename(f.path) == name }
  unless ref
    warn "  WARNING: header #{name} not found; skipping"
    return
  end
  bf = headers_phase.files.find { |b| b.file_ref == ref } || headers_phase.add_file_reference(ref)
  bf.settings = { 'ATTRIBUTES' => ['Public'] }
  puts "  public header: #{name}"
end

# Umbrella (apply_fork.sh copied it to UTM/UTM.h).
umbrella = project.files.find { |f| f.path && File.basename(f.path) == 'UTM.h' }
umbrella ||= project.main_group.new_reference('UTM.h')
ub = headers_phase.files.find { |b| b.file_ref == umbrella } || headers_phase.add_file_reference(umbrella)
ub.settings = { 'ATTRIBUTES' => ['Public'] }
puts '  public header: UTM.h (umbrella)'

%w[
  UTMLegacyQemuConfiguration.h UTMLegacyQemuConfiguration+Constants.h
  UTMLegacyQemuConfiguration+Display.h UTMLegacyQemuConfiguration+Drives.h
  UTMLegacyQemuConfiguration+Miscellaneous.h UTMLegacyQemuConfiguration+Networking.h
  UTMLegacyQemuConfiguration+Sharing.h UTMLegacyQemuConfiguration+System.h
  UTMLegacyQemuConfigurationPortForward.h UTMLogging.h UTMASIFImage.h VMKeyboardMap.h
  UTMProcess.h UTMQemuSystem.h UTMJailbreak.h UTMLegacyViewState.h UTMSpiceIO.h GenerateKey.h
  VMDisplayViewController.h VMDisplayMetalViewController.h VMDisplayMetalViewController+Keyboard.h
  VMKeyboardButton.h VMKeyboardView.h
].each { |h| make_public(project, headers_phase, h) }

# 4. Add the UTMLauncher.swift factory + the UTMOpenClawBundleFix.m embed shim (apply_fork.sh
#    copied both into Platform/iOS).
['Platform/iOS/UTMLauncher.swift', 'Platform/iOS/UTMOpenClawBundleFix.m'].each do |rel|
  base = File.basename(rel)
  ref = project.files.find { |f| f.path && File.basename(f.path) == base }
  ref ||= project.main_group.new_reference(rel)
  unless target.source_build_phase.files.any? { |b| b.file_ref == ref }
    target.source_build_phase.add_file_reference(ref)
  end
  puts "  source: #{base}"
end

# 5. Drop the "Embed Libraries" copy phase (dstSubfolderSpec 10 = Frameworks): the ~60
#    QEMU/dep frameworks ship in OpenClaw's Frameworks/, not nested in UTM.framework.
target.copy_files_build_phases
      .select { |p| p.symbol_dst_subfolder_spec == :frameworks }
      .each do |phase|
        puts "  removing Embed Libraries phase (#{phase.files.count} files)"
        target.build_phases.delete(phase)
        phase.remove_from_project
      end

project.save
puts 'Done. Product = UTM.framework, module = UTM.'
