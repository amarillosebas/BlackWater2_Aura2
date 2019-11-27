using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Audio;

public class Lightning : MonoBehaviour {
	[Space(5f)]
	[Header("Dependencies")]
	public Animator animator;
	public AudioSource audio;
	public AudioClip[] clips;

	void Start () {
		int r = Random.Range(1, 4);
		string t = r + "";
		animator.SetTrigger(t);

		r = Random.Range(0, clips.Length);
		audio.clip = clips[r];
		float s = Random.Range(0f, 1f);
		audio.PlayDelayed(s);

		Destroy(gameObject, 12f);
	}
}
