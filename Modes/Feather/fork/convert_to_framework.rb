#!/usr/bin/env ruby
# frozen_string_literal: true
#
# convert_to_framework.rb  (Feather)
#
# Converts Feather's application target *in place* into an embeddable framework
# (Feather.framework, module "Feather"), inside a fresh Feather clone on CI —
# never against the local F: checkout. Mirrors Modes/Delta/fork.
#
# Usage: ruby convert_to_framework.rb <path-to-Feather.xcodeproj>

require 'xcodeproj'

project_path = ARGV[0] || 'Feather.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Feather' && t.product_type.include?('application') }
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

# --- 3. Promote the bridging-header ObjC headers + umbrella to Public ---------
headers_phase = target.headers_build_phase

%w[MachOUtils.h iconPoc.h].each do |name|
  file_ref = project.files.find { |f| f.path && File.basename(f.path) == name }
  unless file_ref
    warn "  WARNING: header #{name} not found; skipping"
    next
  end
  bf = headers_phase.files.find { |x| x.file_ref == file_ref } || headers_phase.add_file_reference(file_ref)
  bf.settings = { 'ATTRIBUTES' => ['Public'] }
  puts "  public header: #{name}"
end

# Umbrella header (apply_fork.sh copied it to Feather/Feather.h).
umbrella = project.files.find { |f| f.path && File.basename(f.path) == 'Feather.h' }
umbrella ||= project.main_group.new_reference('Feather/Feather.h')
ubf = headers_phase.files.find { |x| x.file_ref == umbrella } || headers_phase.add_file_reference(umbrella)
ubf.settings = { 'ATTRIBUTES' => ['Public'] }
puts '  public header: Feather.h (umbrella)'

# FeatherLauncher.h — public header (OpenClaw's UIKit-only entry point).
launcher_h = project.files.find { |f| f.path && File.basename(f.path) == 'FeatherLauncher.h' }
launcher_h ||= project.main_group.new_reference('Feather/FeatherLauncher.h')
lbf = headers_phase.files.find { |x| x.file_ref == launcher_h } || headers_phase.add_file_reference(launcher_h)
lbf.settings = { 'ATTRIBUTES' => ['Public'] }
puts '  public header: FeatherLauncher.h'

# --- 4. Add FeatherHost.swift + FeatherLauncher.m to the compile sources ------
{ 'FeatherHost.swift' => 'Feather/FeatherHost.swift',
  'FeatherLauncher.m' => 'Feather/FeatherLauncher.m' }.each do |base, path|
  fref = project.files.find { |f| f.path && File.basename(f.path) == base }
  fref ||= project.main_group.new_reference(path)
  unless target.source_build_phase.files.any? { |bf| bf.file_ref == fref }
    target.source_build_phase.add_file_reference(fref)
  end
  puts "  source: #{base}"
end

# --- 5. Drop the app's "Embed Frameworks" copy phase (cores go to OpenClaw) ---
target.copy_files_build_phases
      .select { |p| p.symbol_dst_subfolder_spec == :frameworks }
      .each do |phase|
        puts "  removing Embed Frameworks phase (#{phase.files.count} files)"
        target.build_phases.delete(phase)
        phase.remove_from_project
      end

project.save
puts 'Done. Product = Feather.framework, module = Feather.'
