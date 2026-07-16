#!/usr/bin/env ruby
# frozen_string_literal: true
#
# convert_to_framework.rb <path-to-Yattee.xcodeproj>
#
# Converts Yattee's `Yattee (iOS)` application target *in place* into an embeddable framework
# (Yattee.framework, module "Yattee"). Runs only against a fresh yattee/yattee clone on CI.
#
# The framework name must equal the Swift module name (Yattee) so Clang/Swift can find the module.
# The target has no PRODUCT_MODULE_NAME override, so the module is already "Yattee"; we set
# PRODUCT_NAME=Yattee so the product is Yattee.framework. Yattee's bridging header only pulls
# <ifaddrs.h> + CoreFoundation (no ObjC glue), so it's dropped rather than replaced by an umbrella.

require 'xcodeproj'

project_path = ARGV[0] || 'Yattee.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Yattee (iOS)' }
raise "'Yattee (iOS)' target not found in #{project_path}" unless target

puts "Converting target '#{target.name}' -> Yattee.framework ..."

# 1. Flip the app target into a framework.
target.product_type = 'com.apple.product-type.framework'
product_ref = target.product_reference
product_ref.name = 'Yattee.framework'
product_ref.path = 'Yattee.framework'
product_ref.explicit_file_type = 'wrapper.framework'
product_ref.include_in_index = '0'

# 2. Build settings.
target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = 'Yattee'                # framework name must equal the module name
  s['PRODUCT_MODULE_NAME'] = 'Yattee'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'ai.openclawfoundation.yatteemode'
  s['MACH_O_TYPE'] = 'mh_dylib'
  s['DEFINES_MODULE'] = 'YES'
  s['SKIP_INSTALL'] = 'NO'
  s['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO'
  s['ENABLE_BITCODE'] = 'NO'
  s['DYLIB_INSTALL_NAME_BASE'] = '@rpath'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['INFOPLIST_FILE'] = ''                    # framework plist is generated; the app's is app-shaped

  # Yattee's bridging header only imports <ifaddrs.h> + CoreFoundation — frameworks can't use one,
  # and there's no ObjC glue to preserve, so drop it.
  s.delete('SWIFT_OBJC_BRIDGING_HEADER')

  # MPVKit (mpv + ffmpeg) needs these to link; carry them onto the framework target.
  ldflags = s['OTHER_LDFLAGS']
  ldflags = ldflags.is_a?(Array) ? ldflags.dup : (ldflags ? [ldflags] : ['$(inherited)'])
  ['-lstdc++', '-Wl,-no_compact_unwind'].each { |f| ldflags << f unless ldflags.include?(f) }
  s['OTHER_LDFLAGS'] = ldflags

  # Code-signed by the embedding app, not here.
  s['CODE_SIGNING_ALLOWED'] = 'NO'
  s['CODE_SIGNING_REQUIRED'] = 'NO'
  s['CODE_SIGN_IDENTITY'] = ''
  s['CODE_SIGN_ENTITLEMENTS'] = ''
  s.delete('CODE_SIGN_STYLE')
  s.delete('DEVELOPMENT_TEAM')
  s.delete('PROVISIONING_PROFILE_SPECIFIER')
end

# 3. Add the launcher (apply_fork.sh copied it into Shared/).
launcher = project.files.find { |f| f.path && File.basename(f.path) == 'YatteeLauncher.swift' }
launcher ||= project.main_group.new_reference('Shared/YatteeLauncher.swift')
unless target.source_build_phase.files.any? { |b| b.file_ref == launcher }
  target.source_build_phase.add_file_reference(launcher)
end
puts '  source: YatteeLauncher.swift'

# 4. Drop any embed-app-extension / embed-watch phases (an app-only concept; the share extension
#    "Open in Yattee" doesn't ship inside an embedded framework).
target.copy_files_build_phases
      .select { |p| %i[plug_ins wrapper].include?(p.symbol_dst_subfolder_spec) }
      .each do |phase|
        puts "  removing copy phase (#{phase.symbol_dst_subfolder_spec}, #{phase.files.count} files)"
        target.build_phases.delete(phase)
        phase.remove_from_project
      end

project.save
puts 'Done. Product = Yattee.framework, module = Yattee.'
