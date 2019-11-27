using System.IO;
using UnityEditor;
using UnityEngine;
using System;

public class ReplaceSplatmap : ScriptableWizard {
	public Texture2D Splatmap;
	public Texture2D New ;
	public bool FlipVertical = false;

	void OnWizardUpdate () {
		 helpString = "Replace the existing splatmap of your terrain with a new one.\nDrag the embedded splatmap texture of your terrain to the 'Splatmap box'.\nThen drag the replacement splatmap texture to the 'New' box\nThen hit 'Replace'.";
        isValid = (Splatmap != null) && (New != null);
        //FlipVertical = true;
	}

	void OnWizardCreate () {
		var w = New.width;
		if (Mathf.ClosestPowerOfTwo(w) != w) {
			EditorUtility.DisplayDialog("Wrong size", "Splatmap width and height must be a power of two!", "Cancel"); 
			return;	
		}  

		try {
			var pixels = New.GetPixels();	
			if (FlipVertical) {
				var h = w; // always square in unity
				for (var y = 0; y < h/2; y++) {
					var otherY = h - y - 1;	
					for (var x  = 0; x < w; x++) {
						var swapval = pixels[y*w + x];					
						pixels[y*w + x] = pixels[otherY*w + x];
						pixels[otherY*w + x] = swapval;
					}		
				}
			}
			Splatmap.Resize (New.width, New.height, New.format, true);
			Splatmap.SetPixels (pixels);
			Splatmap.Apply();
		}
		catch (Exception e) {
			EditorUtility.DisplayDialog("Not readable", "The 'New' splatmap must be readable. Make sure the type is Advanced and enable read/write and try again!", "Cancel"); 
			return;
		}
	}

	[MenuItem("Window/Replace Splatmap...")]
	static void Replace () {
	    ScriptableWizard.DisplayWizard(
	        "ReplaceSplatmap", typeof(ReplaceSplatmap), "Replace");
	}
}
