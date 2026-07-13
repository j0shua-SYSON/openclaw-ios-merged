#!/usr/bin/env ruby
# frozen_string_literal: true
#
# convert_to_framework.rb  (Feather)
#
# Converts Feather's application target *in place* into an embeddable framework
# (Feather.framework, module "Feather"), inside a fresh Feather clone on CI.
#
# Feather's project uses Xcode 16 "file system synchronized groups"
# (PBXFileSystemSynchronizedRootGroup). xcodeproj 1.28.1 chokes opening it because
# a synchronized-group membership exception points at a Resources build phase and
# the gem only whitelists Sources/CopyFiles. We monkey-patch that whitelist so the
# project opens, then make MINIMAL edits: flip the target to a framework, add our
# own files (which live OUTSIDE the synced folder, so no double-membership), and
# set build settings. We never mutate the synced groups themselves.
#
# Usage: ruby convert_to_framework.rb <path-to-Feather.xcodeproj>

require 'xcodeproj'

# --- Monkey-patch: allow more build-phase ISAs in the synchronized-group
#     membership exception set so Project.open succeeds on Xcode 16 projects. ----
begin
  O = Xcodeproj::Project::Object
  if O.const_defined?(:PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet)
    klass = O.const_get(:PBXFileSystemSynchronizedGroupBuildPhaseMembershipExceptionSet)
    extra = %i[PBXResourcesBuildPhase PBXHeadersBuildPhase PBXFrameworksBuildPhase]
            .map { |n| O.const_get(n) if O.const_defined?(n) }.compact
    klass.to_one_attributes.each do |attr|
      next unless attr.name == :build_phase
      attr.classes.concat(extra.reject { |c| attr.classes.include?(c) })
    end
    puts "  (monkey-patched synchronized-group exception set: #{extra.map(&:isa).join(', ')})"
  end

  # The exception set's display_name (used when serializing the pbxproj comment)
  # calls build_phase.name; fixed-purpose phases (Resources/Headers/Frameworks/
  # Sources) don't define `name`. Give them one so project.save round-trips.
  %i[PBXResourcesBuildPhase PBXHeadersBuildPhase PBXFrameworksBuildPhase PBXSourcesBuildPhase].each do |n|
    next unless O.const_defined?(n)
    c = O.const_get(n)
    c.send(:define_method, :name) { display_name } unless c.method_defined?(:name)
  end
rescue StandardError => e
  warn "  WARNING: synchronized-group monkey-patch failed: #{e.class}: #{e.message}"
end

project_path = ARGV[0] || 'Feather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Feather' && t.product_type.to_s.include?('application') }
target ||= project.targets.find { |t| t.name == 'Feather' }
raise "Feather app target not found in #{project_path}" unless target

puts "Converting target '#{target.name}' -> Feather.framework ..."

# --- 1. Flip the app target into a framework (bundle name == module name) ----
target.product_type = 'com.apple.product-type.framework'
ref = target.product_reference
ref.name = 'Feather.framework'
ref.path = 'Feather.framework'
ref.explicit_file_type = 'wrapper.framework'
ref.include_in_index = '0'

# --- 2. Build settings on every configuration --------------------------------
header_paths = ['$(inherited)',
                '$(SRCROOT)/FeatherModule',
                '$(SRCROOT)/Feather',
                '$(SRCROOT)/Feather/Utilities',
                '$(SRCROOT)/Feather/Utilities/MachO']

target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_NAME'] = 'Feather'
  s['PRODUCT_MODULE_NAME'] = 'Feather'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'ai.openclawfoundation.feather'
  s['MACH_O_TYPE'] = 'mh_dylib'
  s['DEFINES_MODULE'] = 'YES'
  s['SKIP_INSTALL'] = 'NO'
  s['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO'
  s['INFOPLIST_FILE'] = 'FeatherMode-Info.plist'
  s['GENERATE_INFOPLIST_FILE'] = 'NO'
  s['ENABLE_BITCODE'] = 'NO'
  s['DYLIB_INSTALL_NAME_BASE'] = '@rpath'
  s['LD_RUNPATH_SEARCH_PATHS'] = ['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']
  s['HEADER_SEARCH_PATHS'] = header_paths

  # Frameworks cannot use an ObjC bridging header — the umbrella header replaces it.
  s.delete('SWIFT_OBJC_BRIDGING_HEADER')

  # Frameworks are code-signed by the embedding app, not here.
  s['CODE_SIGNING_ALLOWED'] = 'NO'
  s['CODE_SIGNING_REQUIRED'] = 'NO'
  s['CODE_SIGN_IDENTITY'] = ''
  s['CODE_SIGN_ENTITLEMENTS'] = ''
  s.delete('CODE_SIGN_STYLE')
  s.delete('DEVELOPMENT_TEAM')
  s.delete('PROVISIONING_PROFILE_SPECIFIER')
end

# --- 3. Add our files (all under the non-synced FeatherModule/ dir) -----------
group = project.main_group.find_subpath('FeatherModule', true)
group.set_source_tree('SOURCE_ROOT')

def add_source(project, group, target, path, base)
  ref = project.files.find { |f| f.path == path } || group.new_reference(path)
  ref.set_source_tree('SOURCE_ROOT')
  unless target.source_build_phase.files.any? { |bf| bf.file_ref == ref }
    target.source_build_phase.add_file_reference(ref)
  end
  puts "  source: #{base}"
  ref
end

def add_public_header(project, group, target, path, base)
  ref = project.files.find { |f| f.path == path } || group.new_reference(path)
  ref.set_source_tree('SOURCE_ROOT')
  hp = target.headers_build_phase
  bf = hp.files.find { |x| x.file_ref == ref } || hp.add_file_reference(ref)
  bf.settings = { 'ATTRIBUTES' => ['Public'] }
  puts "  public header: #{base}"
  ref
end

add_source(project, group, target, 'FeatherModule/FeatherHost.swift', 'FeatherHost.swift')
add_source(project, group, target, 'FeatherModule/FeatherLauncher.m', 'FeatherLauncher.m')
add_public_header(project, group, target, 'FeatherModule/Feather.h', 'Feather.h (umbrella)')
add_public_header(project, group, target, 'FeatherModule/FeatherLauncher.h', 'FeatherLauncher.h')

# --- 4. Drop the app's "Embed Frameworks" copy phase (if any) ----------------
target.copy_files_build_phases
      .select { |p| p.symbol_dst_subfolder_spec == :frameworks }
      .each do |phase|
        puts "  removing Embed Frameworks phase (#{phase.files.count} files)"
        target.build_phases.delete(phase)
        phase.remove_from_project
      end

project.save
puts 'Done. Product = Feather.framework, module = Feather.'
