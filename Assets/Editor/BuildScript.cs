using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.SceneManagement;

public static class BuildScript
{
    public static void BuildIOS()
    {
        Directory.CreateDirectory("Assets/Scenes");
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        EditorSceneManager.SaveScene(scene, "Assets/Scenes/Main.unity");
        PlayerSettings.productName = "Capital Fall";
        PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.iOS, "com.capitalfall.game");
        PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
        PlayerSettings.iOS.sdkVersion = iOSSdkVersion.DeviceSDK;
        PlayerSettings.iOS.appleEnableAutomaticSigning = false;
        var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions {
            scenes = new[] { "Assets/Scenes/Main.unity" },
            locationPathName = "build/iOS",
            target = BuildTarget.iOS,
            options = BuildOptions.None });
        if (report.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
            EditorApplication.Exit(1);
    }
}
