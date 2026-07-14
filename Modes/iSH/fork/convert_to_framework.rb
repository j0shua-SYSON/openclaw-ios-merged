#!/usr/bin/env ruby
# frozen_string_literal: true
#
# convert_to_framework.rb
#
# Converts iSH's application target *in place* into an embeddable framework
# (iSH.framework). Runs only against a fresh iSH clone on CI.
#
# iSH is all ObjC/C: the `iSH` app target compiles only 3 device .m files and links
# libiSHApp.a (the app code: AppDelegate/TerminalViewController/main/...) plus the
# meson-built emulator (libish.a/libish_emu.a/libfakefs.a) and libarchive.a. Flipping
# the app target's product type reuses that whole proven build graph — the meson
# "Run Script" phases, "Download Root", "Compile JavaScript", and every link — and
# yields a self-contained iSH.framework.
#
# Usage: ruby convert_to_framework.rb <path-to-iSH.xcodeproj>

require 'xcodeproj'

project_path = ARGV[0] || 'iSH.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'iSH' }
raise "iSH app target not found in #{project_path}" unless target

puts "Converting target '#{target.name}' -> iSH.framework ..."

# ---------------------------------------------------------------------------
# 1. Flip the app target into a framework.
# ---------------------------------------------------------------------------
target.product_type = 'com.apple.product-type.framework'

product_ref = target.product_reference
product_ref.name = 'iSH.framework'
product_ref.path = 'iSH.framework'
product_ref.explicit_file_type = 'wrapper.framework'
product_ref.include_in_index = '0'

# ---------------------------------------------------------------------------
# 2. Build settings (applied to every configuration; existing keys preserved).
# ---------------------------------------------------------------------------
target.build_configurations.each do |config|
  s = config.build_settings

  s['PRODUCT_NAME'] = 'iSH'
  s['PRODUCT_MODULE_NAME'] = 'iSH'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'ai.openclawfoundation.ishmode'
  s['MACH_O_TYPE'] = 'mh_dylib'
  s['DEFINES_MODULE'] = 'YES'
  s['SKIP_INSTALL'] = 'NO'
  s['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO'
  s['INFOPLIST_FILE'] = 'iSHMode-Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['ENABLE_BITCODE'] = 'NO'
  s['DYLIB_INSTALL_NAME_BASE'] = '@rpath'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']

  # Frameworks are code-signed by the embedding app, not here.
  s['CODE_SIGNING_ALLOWED'] = 'NO'
  s['CODE_SIGNING_REQUIRED'] = 'NO'
  s['CODE_SIGN_IDENTITY'] = ''
  s['CODE_SIGN_ENTITLEMENTS'] = ''
  s.delete('CODE_SIGN_STYLE')
  s.delete('DEVELOPMENT_TEAM')
  s.delete('PROVISIONING_PROFILE_SPECIFIER')
end

# ---------------------------------------------------------------------------
# 3. Drop the iSHFileProvider extension: its "Embed Foundation Extensions" copy
#    phase (dstSubfolderSpec = plug_ins) and the target dependency. The embed we
#    want for the mode is just the terminal; Files.app integration needs an
#    app-group entitlement shared app<->extension that OpenClaw doesn't carry.
# ---------------------------------------------------------------------------
target.copy_files_build_phases
      .select { |p| p.symbol_dst_subfolder_spec == :plug_ins }
      .each do |phase|
        puts "  removing extension-embed phase (#{phase.files.count} files)"
        target.build_phases.delete(phase)
        phase.remove_from_project
      end

target.dependencies
      .select { |d| d.target && d.target.name == 'iSHFileProvider' }
      .each do |dep|
        puts '  removing iSHFileProvider dependency'
        target.dependencies.delete(dep)
        dep.remove_from_project
      end

# ---------------------------------------------------------------------------
# 4. Add the iSHLauncher ObjC boundary (apply_fork.sh copied it into app/).
# ---------------------------------------------------------------------------
launcher_m = project.files.find { |f| f.path && File.basename(f.path) == 'iSHLauncher.m' }
launcher_m ||= project.main_group.new_reference('app/iSHLauncher.m')
unless target.source_build_phase.files.any? { |bf| bf.file_ref == launcher_m }
  target.source_build_phase.add_file_reference(launcher_m)
end
puts '  source: iSHLauncher.m'

headers_phase = target.headers_build_phase
launcher_h = project.files.find { |f| f.path && File.basename(f.path) == 'iSHLauncher.h' }
launcher_h ||= project.main_group.new_reference('app/iSHLauncher.h')
launcher_bf = headers_phase.files.find { |bf| bf.file_ref == launcher_h }
launcher_bf ||= headers_phase.add_file_reference(launcher_h)
launcher_bf.settings = { 'ATTRIBUTES' => ['Public'] }
puts '  public header: iSHLauncher.h'

project.save
puts 'Done. Product = iSH.framework.'
