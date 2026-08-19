#!/usr/bin/env python3
import plistlib
import uuid
from pathlib import Path

project_dir = Path("/Users/andychen/Desktop/beauty-clinic-ios/BeautyClinic")
xcodeproj_path = project_dir / "BeautyClinic.xcodeproj"

# Ensure the xcodeproj directory exists
(xcodeproj_path / "project.pbxproj").parent.mkdir(parents=True, exist_ok=True)

# Generate unique UUIDs
def gen_uuid():
    return str(uuid.uuid4()).upper().replace("-", "")[:24]

# File references (Swift files)
files = [
    "App.swift",
    "Models/Customer.swift", "Models/User.swift", "Models/Package.swift", "Models/Store.swift", "Models/Transaction.swift",
    "Services/SupabaseClient+Auth.swift", "Services/SupabaseClient+Environment.swift", "Services/SupabaseClient.swift",
    "Views/ContentView.swift", "Views/MainTabView.swift", "Views/HomeView.swift", "Views/LoginView.swift",
    "Views/Auth/OTPVerificationView.swift",
    "Views/Common/SearchBar.swift", "Views/Common/AvatarView.swift", "Views/Common/FilterBar.swift",
    "Views/CustomerDetailView.swift", "Views/CustomerEditView.swift", "Views/CustomerListView.swift", "Views/CustomerRow.swift",
    "Views/PackageListView.swift", "Views/Packages/PackageEditView.swift", "Views/Packages/PackageRow.swift",
    "Views/SettingsView.swift",
    "Views/StoreDetailView.swift", "Views/StoreEditView.swift", "Views/StoreListView.swift", "Views/StoreRow.swift",
    "Views/TransactionListView.swift", "Views/TransactionRecordView.swift", "Views/TransactionRow.swift",
]

# Filter files that actually exist
existing_files = []
for f in files:
    if (project_dir / f).exists():
        existing_files.append(f)
files = existing_files

uuids = {f: gen_uuid() for f in ["project", "group", "target", "debug_config", "release_config", "config_list", "target_config_list"]}

file_uuids = {}
for i, f in enumerate(files):
    file_uuids[f] = gen_uuid()

build_file_uuids = {}
for f in files:
    build_file_uuids[f] = gen_uuid()

# Build project structure
objects = {}

# PBXFileReference
for f, uid in file_uuids.items():
    ext = Path(f).suffix
    objects[uid] = {
        "isa": "PBXFileReference",
        "lastKnownFileType": "sourcecode.swift" if ext == ".swift" else ("text.plist.xml" if f == "Info.plist" else "folder"),
        "path": f,
        "sourceTree": "<group>",
    }

# PBXGroup (project group)
group_uid = uuids["group"]
objects[group_uid] = {
    "isa": "PBXGroup",
    "children": [file_uuids[f] for f in files],
    "path": "BeautyClinic",
    "sourceTree": "<group>",
}

# PBXNativeTarget
target_uid = uuids["target"]
objects[target_uid] = {
    "isa": "PBXNativeTarget",
    "buildConfigurationList": uuids["target_config_list"],
    "buildPhases": [
        gen_uuid(),  # Sources
        gen_uuid(),  # Resources
    ],
    "name": "BeautyClinic",
    "productReference": gen_uuid(),
    "productType": "com.apple.product-type.application",
}

# PBXSourcesBuildPhase
sources_uid = objects[target_uid]["buildPhases"][0]
objects[sources_uid] = {
    "isa": "PBXSourcesBuildPhase",
    "buildActionMask": 2147483647,
    "files": [],
}
for f in files:
    bf_uid = build_file_uuids[f]
    objects[bf_uid] = {"isa": "PBXBuildFile", "fileRef": file_uuids[f]}
    objects[sources_uid]["files"].append(bf_uid)

# PBXResourcesBuildPhase
resources_uid = objects[target_uid]["buildPhases"][1]
objects[resources_uid] = {
    "isa": "PBXResourcesBuildPhase",
    "buildActionMask": 2147483647,
    "files": [],
}

# PBXProject
project_uid = uuids["project"]
objects[project_uid] = {
    "isa": "PBXProject",
    "attributes": {
        "LastUpgradeCheck": "1500",
        "ORGANIZATIONNAME": "Andy Chen",
        "TargetAttributes": [
            {
                "DevelopmentTeam": "",
                "TargetAttributes": {target_uid: {"ProvisioningStyle": "Automatic"}}
            }
        ]
    },
    "buildConfigurationList": uuids["config_list"],
    "compatibilityVersion": "Xcode 14.0",
    "developmentRegion": "en",
    "hasScannedForEncodings": 0,
    "knownRegions": ["en", "Base"],
    "mainGroup": group_uid,
    "projectDirPath": "",
    "projectRoot": "",
    "targets": [target_uid],
}

# PBXContainerItemProxy (for app extension, etc. - not needed here)

# XCBuildConfiguration
debug_uid = uuids["debug_config"]
release_uid = uuids["release_config"]

objects[debug_uid] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": {
        "CODE_SIGN_STYLE": "Automatic",
        "DEBUG_INFORMATION_FORMAT": "dwarf",
        "ENABLE_STRICT_OBJC_SENDER_MISMATCH": "NO",
        "INFOPLIST_FILE": "Info.plist",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "OTHER_SWIFT_FLAGS": "-D DEBUG",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.andychen.BeautyClinic",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
        "SWIFT_VERSION": "5.9",
    },
    "name": "Debug",
}

objects[release_uid] = {
    "isa": "XCBuildConfiguration",
    "buildSettings": {
        "CODE_SIGN_STYLE": "Automatic",
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
        "ENABLE_STRICT_OBJC_SENDER_MISMATCH": "NO",
        "INFOPLIST_FILE": "Info.plist",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.andychen.BeautyClinic",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "RELEASE",
        "SWIFT_VERSION": "5.9",
    },
    "name": "Release",
}

# XCConfigurationList
config_list_uid = uuids["config_list"]
target_config_list_uid = uuids["target_config_list"]

objects[config_list_uid] = {
    "isa": "XCConfigurationList",
    "buildConfigurations": [debug_uid, release_uid],
    "defaultConfigurationIsVisible": 0,
    "defaultConfigurationName": "Release",
}

objects[target_config_list_uid] = {
    "isa": "XCConfigurationList",
    "buildConfigurations": [debug_uid, release_uid],
    "defaultConfigurationIsVisible": 0,
    "defaultConfigurationName": "Release",
}

# PBXTargetDependency (not needed for single target)

# PBXApplicationExtensionProxy, PBXWatchApplicationExtensionProxy (not needed)

# Root object
root_object = project_uid

# Build the final plist structure
pbxproj = {
    "archiveVersion": "1",
    "classes": {},
    "objectVersion": 56,
    "objects": objects,
    "rootObject": root_object,
}

# Write to file
output_path = xcodeproj_path / "project.pbxproj"
with open(output_path, "wb") as f:
    plistlib.dump(pbxproj, f)

print(f"✅ Generated clean Xcode project at: {output_path}")
print(f"   Total files referenced: {len(files)}")
print(f"   Files: {', '.join(files[:5])}{'...' if len(files) > 5 else ''}")
