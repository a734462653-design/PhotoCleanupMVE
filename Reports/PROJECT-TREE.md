# PhotoCleanupMVE 工程目录结构

```text
PhotoCleanupMVE/
├─ .github/
│  └─ workflows/
│     └─ ci.yml
├─ PhotoCleanupMVE.xcodeproj/
│  ├─ project.pbxproj
│  └─ xcshareddata/
│     └─ xcschemes/
│        └─ PhotoCleanupMVE.xcscheme
├─ PhotoCleanupMVE/
│  ├─ App/
│  │  ├─ CleanupCoordinator.swift
│  │  └─ PhotoCleanupMVEApp.swift
│  ├─ Core/
│  │  ├─ AssetModels.swift
│  │  ├─ S3StateMachine.swift
│  │  ├─ S4StateMachine.swift
│  │  ├─ S5StateMachine.swift
│  │  └─ SessionPersistence.swift
│  ├─ Services/
│  │  ├─ AssetSizeScanner.swift
│  │  ├─ PhotoDeletionService.swift
│  │  └─ PhotoLibraryService.swift
│  ├─ Features/
│  │  ├─ S3/
│  │  │  └─ S3View.swift
│  │  ├─ S4/
│  │  │  └─ S4View.swift
│  │  ├─ S5/
│  │  │  └─ S5View.swift
│  │  └─ Shared/
│  │     └─ ThumbnailView.swift
│  ├─ Assets.xcassets/
│  │  ├─ Contents.json
│  │  └─ RECENTLY_DELETED_PLACEHOLDER.imageset/
│  │     ├─ Contents.json
│  │     └─ RECENTLY_DELETED_PLACEHOLDER.png
│  └─ Info.plist
├─ PhotoCleanupMVETests/
│  ├─ CollectionInvariantTests.swift
│  ├─ S3StateMachineTests.swift
│  ├─ S4StateMachineTests.swift
│  ├─ S5StateMachineTests.swift
│  ├─ SnapshotInvariantTests.swift
│  └─ VolumeFormattingTests.swift
├─ Scripts/
│  ├─ selfcheck.ps1
│  └─ test-xcode.sh
├─ Reports/
│  ├─ PROJECT-TREE.md
│  ├─ SELF-VERIFICATION.md
│  └─ UNDECIDED-ITEMS.md
├─ .gitattributes
├─ .gitignore
└─ README.md
```
