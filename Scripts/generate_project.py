#!/usr/bin/env python3
"""Generate a dependency-free, deterministic Xcode project. Python standard library only."""
from pathlib import Path
import hashlib,json
R=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def q(s):return json.dumps(str(s))
objects={}
def obj(name,body):objects[uid(name)]=body;return uid(name)
sources=sorted((R/'Reader').glob('*.swift'))+sorted((R/'Reader').glob('*.c'))
tests=sorted((R/'ReaderTests').glob('*.swift'))
refs=[];builds=[];trefs=[];tbuilds=[]
for p in sources+tests:
 rel=p.relative_to(R).as_posix();ref=obj(rel,'isa = PBXFileReference; lastKnownFileType = '+('sourcecode.c.c' if p.suffix=='.c' else 'sourcecode.swift')+'; path = '+q(rel)+'; sourceTree = SOURCE_ROOT;')
 build=obj('build:'+rel,f'isa = PBXBuildFile; fileRef = {ref};')
 if p in tests:trefs.append(ref);tbuilds.append(build)
 else:refs.append(ref);builds.append(build)
def arr(ids):return '('+','.join(ids)+',)' if ids else '()'
appProduct=obj('appProduct','isa = PBXFileReference; explicitFileType = wrapper.application; path = LocalReader.app; sourceTree = BUILT_PRODUCTS_DIR;')
testProduct=obj('testProduct','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = LocalReaderTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = {arr([appProduct,testProduct])}; name = Products; sourceTree = "<group>";')
root=obj('root',f'isa = PBXGroup; children = {arr(refs+trefs+[products])}; sourceTree = "<group>";')
sourcePhase=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(builds)}; runOnlyForDeploymentPostprocessing = 0;')
testPhase=obj('testSources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(tbuilds)}; runOnlyForDeploymentPostprocessing = 0;')
framework=obj('framework','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
resources=obj('resources','isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
for target in ['project','app','tests']:
 configs=[]
 for mode in ['Debug','Release']:
  settings={'IPHONEOS_DEPLOYMENT_TARGET':'16.0','SWIFT_VERSION':'5.0','SDKROOT':'iphoneos','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','TARGETED_DEVICE_FAMILY':'1,2','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if mode=='Debug' else '-O','DEBUG_INFORMATION_FORMAT':'dwarf','ENABLE_TESTABILITY':'YES' if mode=='Debug' else 'NO','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if mode=='Debug' else ''}
  if target=='app':settings.update({'PRODUCT_BUNDLE_IDENTIFIER':'com.kupetis.localreader','PRODUCT_NAME':'LocalReader','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_CFBundleDisplayName':'本地阅读·开发版','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','SWIFT_OBJC_BRIDGING_HEADER':'Reader/ZipBridge.h','OTHER_LDFLAGS':'-lz','CURRENT_PROJECT_VERSION':'1','MARKETING_VERSION':'0.1.0','CODE_SIGN_STYLE':'Automatic','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator'})
  if target=='tests':settings.update({'PRODUCT_BUNDLE_IDENTIFIER':'com.kupetis.localreader.tests','PRODUCT_NAME':'LocalReaderTests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/LocalReader.app/LocalReader','BUNDLE_LOADER':'$(TEST_HOST)','SWIFT_OBJC_BRIDGING_HEADER':'Reader/ZipBridge.h','OTHER_LDFLAGS':'-lz'})
  configs.append(obj(target+mode,'isa = XCBuildConfiguration; buildSettings = {'+' '.join(k+' = '+q(v)+';' for k,v in settings.items())+'}; name = '+mode+';'))
 obj(target+'ConfigList','isa = XCConfigurationList; buildConfigurations = '+arr(configs)+'; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
app=obj('app',f'isa = PBXNativeTarget; buildConfigurationList = {uid("appConfigList")}; buildPhases = {arr([sourcePhase,framework,resources])}; buildRules = (); dependencies = (); name = LocalReader; productName = LocalReader; productReference = {appProduct}; productType = "com.apple.product-type.application";')
proxy=obj('proxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {app}; remoteInfo = LocalReader;')
dep=obj('dependency',f'isa = PBXTargetDependency; target = {app}; targetProxy = {proxy};')
targetTests=obj('tests',f'isa = PBXNativeTarget; buildConfigurationList = {uid("testsConfigList")}; buildPhases = {arr([testPhase])}; buildRules = (); dependencies = {arr([dep])}; name = LocalReaderTests; productName = LocalReaderTests; productReference = {testProduct}; productType = "com.apple.product-type.bundle.unit-test";')
project=obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 1640; TargetAttributes = {{ {targetTests} = {{ TestTargetID = {app}; }}; }}; }}; buildConfigurationList = {uid("projectConfigList")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en,Base); mainGroup = {root}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {arr([app,targetTests])};')
folder=R/'LocalReader.xcodeproj';folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = { '+v+' };' for k,v in objects.items())+'\n}; rootObject = '+project+'; }\n',encoding='utf-8')
def bref(i,name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{i}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:LocalReader.xcodeproj"/>'
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{bref(app,'LocalReader.app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{bref(targetTests,'LocalReaderTests.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{bref(app,'LocalReader.app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{bref(app,'LocalReader.app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
p=folder/'xcshareddata/xcschemes';p.mkdir(parents=True,exist_ok=True);(p/'LocalReader.xcscheme').write_text(scheme,encoding='utf-8')
print(f'Generated project: {len(sources)} app source files, {len(tests)} test source files')
