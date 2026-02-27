require 'xcodeproj'

project_path = '/Users/azash/Desktop/Oxford-Pronunciation-App/ios/App/App.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

# Add AuthService.swift
auth_service_path = '/Users/azash/Desktop/Oxford-Pronunciation-App/ios/App/App/Services/AuthService.swift'
file_ref = project.main_group.new_reference(auth_service_path)
target.add_file_references([file_ref])
puts "Added AuthService.swift"

# Add LoginSheetView.swift
login_sheet_path = '/Users/azash/Desktop/Oxford-Pronunciation-App/ios/App/App/Features/LoginSheetView.swift'
file_ref2 = project.main_group.new_reference(login_sheet_path)
target.add_file_references([file_ref2])
puts "Added LoginSheetView.swift"

project.save
puts "Saved project"
