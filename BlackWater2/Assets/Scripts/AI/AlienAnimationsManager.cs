using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AlienAnimationsManager : MonoBehaviour {
	[Space(5f)]
	[Header("Variables")]
	public Animator animator;

	void Start () {
		AnimatorStateInfo state = animator.GetCurrentAnimatorStateInfo(0);
		animator.Play(state.fullPathHash, -1, Random.Range(0f, 1f));
	}
}
