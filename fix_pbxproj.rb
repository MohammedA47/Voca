require 'xcodeproj'

project_path = '/Users/azash/Desktop/Oxford-Pronunciation-App/ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Clean all references
target.source_build_phase.files.each do |file|
  if file.file_ref && file.file_ref.path && (file.file_ref.path.include?('AuthService.swift') || file.file_ref.path.include?('LoginSheetView.swift'))
    target.source_build_phase.remove_build_file(file)
  end
end

project.main_group.recursive_children.each do |ref|
  if ref.is_a?(Xcodeproj::Project::Object::PBXFileReference) && (ref.path.include?('AuthService.swift') || ref.path.include?('LoginSheetView.swift'))
    ref.remove_from_project
  end
end

# Add exactly ONE reference
services_group = project.main_group.find_subpath('App/Services', true)
auth_ref = services_group.new_file('/Users/azash/Desktop/Oxford-Pronunciation-App/ios/App/App/Services/AuthService.swift')
target.source_build_phase.add_file_reference(auth_ref)

features_group = project.main_group.find_subpath('App/Features', true)
login_ref = features_group.new_file('/Users/azash/Desktop/Oxford-Pronunciation-App/ios/App/App/Features/LoginSheetView.swift')
target.source_build_phase.add_file_reference(login_ref)

project.save
