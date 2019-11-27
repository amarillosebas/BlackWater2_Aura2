using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LightningManager : MonoBehaviour {
	[Space(5f)]
	[Header("Dependencies")]
	public GameObject lightning;

	[Space(5f)]
	[Header("Variables")]
	public float levelRadius;
	public float minWaitTime;
	public float maxWaitTime;

	void Start () {
		StartCoroutine(Storm());
	}
	
	IEnumerator Storm () {
		yield return new WaitForSeconds(Random.Range(minWaitTime, maxWaitTime));
		Vector2 randomPoint = Random.insideUnitCircle * levelRadius;
		Vector3 randomPos = new Vector3(randomPoint.x, 0f, randomPoint.y);
		Instantiate(lightning, randomPos, Quaternion.identity);
		StartCoroutine(Storm());
	}
}
