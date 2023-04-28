using System;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityToolbarExtender;

static class ToolbarStyles
{
	public static readonly GUIStyle commandButtonStyle;

	static ToolbarStyles()
	{
		commandButtonStyle = new GUIStyle("Command")
		{
			fontSize = 12,
			alignment = TextAnchor.MiddleCenter,
			imagePosition = ImagePosition.ImageAbove,
			fontStyle = FontStyle.Bold,
			fixedWidth = 60
		};
	}
}

[InitializeOnLoad]
public class ToolbarButtons
{
	static ToolbarButtons()
	{
		ToolbarExtender.LeftToolbarGUI.Add(OnToolbarLeftGUI);
		ToolbarExtender.RightToolbarGUI.Add(OnToolbarRightGUI);
	}

	static void OnToolbarLeftGUI()
	{
		GUILayout.FlexibleSpace();

		if (GUILayout.Button(new GUIContent("定位项目", "通过Explorer定位打开"), ToolbarStyles.commandButtonStyle))
		{
			EditorUtility.RevealInFinder(Application.dataPath);
		}
	}

	static void OnToolbarRightGUI()
	{
		if (GUILayout.Button(new GUIContent("主场景", "main scene"), ToolbarStyles.commandButtonStyle))
		{
			if (Application.isPlaying)
				return;

			if (EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
			{
				EditorSceneManager.OpenScene("Assets/Scenes/Main.unity");
			}
		}

		GUILayout.FlexibleSpace();
	}
}
