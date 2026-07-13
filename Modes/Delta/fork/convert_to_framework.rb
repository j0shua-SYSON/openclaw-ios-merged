#!/usr/bin/env ruby
# frozen_string_literal: true
#
# convert_to_framework.rb
#
# Converts Delta's application target *in place* into an embeddable framework
# (DeltaMode.framework, Swift module name kept as "Delta"). Runs only against a
# fresh Delta clone on CI — never against the local F: checkout.
#
# Why in-place instead of a brand-new target: the existing "Delta" app target
# already carries the full, proven build graph — every source/resource file, all
# core/DeltaFeatures/SPM links, and the CocoaPods integration (Pods-Delta
# xcconfig + script phases). Flipping its product type and a handful of settings
# reuses all of that; a hand-built duplicate target would have to reproduce it.
#
# Usage: ruby convert_to_framework.rb <path-to-Delta.xcodeproj>

require 'xcodeproj'

project_path = ARGV[0] || 'Delta.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Delta' }
raise "Delta app target not found in #{project_path}" unless target

puts "Converting target '#{target.name}' -> Delta.framework ..."

# ---------------------------------------------------------------------------
# 1. Flip the app target into a framework.
#    Bundle name MUST equal the Swift/Clang module name (Delta): for a mixed
#    ObjC+Swift framework, Clang locates the underlying ObjC module by *bundle
#    name* (Delta.framework -> `framework module Delta`). A mismatched product
#    name (e.g. DeltaMode.framework) yields "Unable to find module dependency:
#    'Delta'". Keeping the module "Delta" also keeps storyboards' customModule
#    and the scene manifest resolving. Target keeps its name "Delta" so the
#    CocoaPods (Pods-Delta) integration and the shared scheme stay wired.
# ---------------------------------------------------------------------------
target.product_type = 'com.apple.product-type.framework'

product_ref = target.product_reference
product_ref.name = 'Delta.framework'
product_ref.path = 'Delta.framework'
product_ref.explicit_file_type = 'wrapper.framework'
product_ref.include_in_index = '0'

# ---------------------------------------------------------------------------
# 2. Build settings (applied to every configuration; existing keys preserved).
# ---------------------------------------------------------------------------
target.build_configurations.each do |config|
  s = config.build_settings

  s['PRODUCT_NAME'] = 'Delta'
  s['PRODUCT_MODULE_NAME'] = 'Delta' # storyboards use customModule="Delta"; keep it.
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'ai.openclawfoundation.deltamode'
  s['MACH_O_TYPE'] = 'mh_dylib'
  s['DEFINES_MODULE'] = 'YES'
  s['SKIP_INSTALL'] = 'NO'
  s['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'NO'
  s['INFOPLIST_FILE'] = 'DeltaMode-Info.plist'
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

  # Ensure BETA so registerCores() registers every system's core.
  cond = (s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] || '$(inherited)').to_s
  s['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = "#{cond} BETA".strip unless cond.include?('BETA')
end

# ---------------------------------------------------------------------------
# 3. Promote the three bridging-header ObjC headers + the umbrella to Public.
# ---------------------------------------------------------------------------
headers_phase = target.headers_build_phase

public_headers = %w[ControllerSkinConfigurations.h GameSetting.h NSFetchedResultsController+Conveniences.h]
public_headers.each do |name|
  file_ref = project.files.find { |f| f.path && File.basename(f.path) == name }
  unless file_ref
    warn "  WARNING: header #{name} not found; skipping"
    next
  end
  build_file = headers_phase.files.find { |bf| bf.file_ref == file_ref }
  build_file ||= headers_phase.add_file_reference(file_ref)
  build_file.settings = { 'ATTRIBUTES' => ['Public'] }
  puts "  public header: #{name}"
end

# Umbrella header (apply_fork.sh copied it to Delta/Delta.h in the clone).
umbrella_ref = project.files.find { |f| f.path && File.basename(f.path) == 'Delta.h' }
umbrella_ref ||= project.main_group.new_reference('Delta/Delta.h')
umbrella_bf = headers_phase.files.find { |bf| bf.file_ref == umbrella_ref }
umbrella_bf ||= headers_phase.add_file_reference(umbrella_ref)
umbrella_bf.settings = { 'ATTRIBUTES' => ['Public'] }
puts '  public header: Delta.h (umbrella)'

# ---------------------------------------------------------------------------
# 4. Add the DeltaHost.swift factory + DeltaLauncher ObjC boundary.
# ---------------------------------------------------------------------------
host_ref = project.files.find { |f| f.path && File.basename(f.path) == 'DeltaHost.swift' }
host_ref ||= project.main_group.new_reference('Delta/DeltaHost.swift')
unless target.source_build_phase.files.any? { |bf| bf.file_ref == host_ref }
  target.source_build_phase.add_file_reference(host_ref)
end
puts '  source: DeltaHost.swift'

# DeltaLauncher.m — pure-ObjC shim compiled into the framework.
launcher_m = project.files.find { |f| f.path && File.basename(f.path) == 'DeltaLauncher.m' }
launcher_m ||= project.main_group.new_reference('Delta/DeltaLauncher.m')
unless target.source_build_phase.files.any? { |bf| bf.file_ref == launcher_m }
  target.source_build_phase.add_file_reference(launcher_m)
end
puts '  source: DeltaLauncher.m'

# DeltaLauncher.h — public header (OpenClaw's UIKit-only entry point).
launcher_h = project.files.find { |f| f.path && File.basename(f.path) == 'DeltaLauncher.h' }
launcher_h ||= project.main_group.new_reference('Delta/DeltaLauncher.h')
launcher_bf = headers_phase.files.find { |bf| bf.file_ref == launcher_h }
launcher_bf ||= headers_phase.add_file_reference(launcher_h)
launcher_bf.settings = { 'ATTRIBUTES' => ['Public'] }
puts '  public header: DeltaLauncher.h'

# ---------------------------------------------------------------------------
# 5. Drop the app's "Embed Frameworks" copy phase. Cores must sit in OpenClaw's
#    Frameworks/ (flat), not nested inside DeltaMode.framework/Frameworks.
# ---------------------------------------------------------------------------
target.copy_files_build_phases
      .select { |p| p.symbol_dst_subfolder_spec == :frameworks }
      .each do |phase|
        puts "  removing Embed Frameworks phase (#{phase.files.count} files)"
        target.build_phases.delete(phase)
        phase.remove_from_project
      end

project.save
puts "Done. Product = Delta.framework, module = Delta."
