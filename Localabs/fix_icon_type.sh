#!/bin/bash
# Post-xcodegen fix: XcodeGen doesn't support lastKnownFileType overrides for
# custom folder types. This patches the pbxproj so AppIcon.icon is recognized
# as an Icon Composer bundle (folder.iconcomposer.icon) instead of a plain folder.
sed -i '' 's/lastKnownFileType = folder; name = AppIcon.icon/lastKnownFileType = folder.iconcomposer.icon; name = AppIcon.icon/' \
  Localabs.xcodeproj/project.pbxproj
echo "✅ Patched AppIcon.icon file type in project.pbxproj"
