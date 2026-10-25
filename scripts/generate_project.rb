require 'xcodeproj'
project = Xcodeproj::Project.new('WordCheck.xcodeproj')
app = project.new_target(:application, 'WordCheck', :ios, '26.0')
app.build_configurations.each do |c|
  c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'com.raunak.wordcheck', 'SWIFT_VERSION'=>'5.0', 'GENERATE_INFOPLIST_FILE'=>'NO', 'INFOPLIST_FILE'=>'WordCheck/Info.plist', 'INFOPLIST_KEY_CFBundleDisplayName'=>'Word check', 'INFOPLIST_KEY_UILaunchScreen_Generation'=>'YES', 'INFOPLIST_KEY_UISupportedInterfaceOrientations'=>'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight', 'TARGETED_DEVICE_FAMILY'=>'1,2', 'CODE_SIGN_STYLE'=>'Automatic'})
end
if ENV['WORDCHECK_TEAM_ID']
  app.build_configurations.each { |c| c.build_settings['DEVELOPMENT_TEAM'] = ENV['WORDCHECK_TEAM_ID'] }
end
group = project.main_group.new_group('WordCheck', 'WordCheck')
Dir['WordCheck/*.swift'].each { |f| app.source_build_phase.add_file_reference(group.new_file(File.basename(f))) }
app.resources_build_phase.add_file_reference(group.new_file('PrivacyInfo.xcprivacy'))
app.resources_build_phase.add_file_reference(group.new_file('Privacy.txt'))
data = group.new_group('Data', 'Data')
Dir['WordCheck/Data/*.txt'].each { |f| app.resources_build_phase.add_file_reference(data.new_file(File.basename(f))) }
app.resources_build_phase.add_file_reference(group.new_file('Assets.xcassets'))
app.build_configurations.each { |c| c.build_settings['ASSETCATALOG_COMPILER_APPICON_NAME'] = 'AppIcon' }
tests = project.new_target(:ui_test_bundle, 'WordCheckUITests', :ios, '26.0')
tests.add_dependency(app)
test_group = project.main_group.new_group('WordCheckUITests', 'WordCheckUITests')
Dir['WordCheckUITests/*.swift'].each { |f| tests.source_build_phase.add_file_reference(test_group.new_file(File.basename(f))) }
tests.build_configurations.each do |c|
  c.build_settings.merge!({'PRODUCT_BUNDLE_IDENTIFIER'=>'com.raunak.wordcheck.uitests', 'SWIFT_VERSION'=>'5.0', 'GENERATE_INFOPLIST_FILE'=>'YES', 'CODE_SIGN_STYLE'=>'Automatic', 'TEST_TARGET_NAME'=>'WordCheck'})
end
project.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.set_launch_target(app)
scheme.add_test_target(tests)

scheme.save_as(project.path, 'WordCheck', true)
