using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class UFOLightsManager : MonoBehaviour {
	[Space(5f)]
	[Header("Dependencies")]
	public Renderer[] lightRenderers;
	public Light[] lights;
	public Light beamLight;
	public Transform player;

	[Space(5f)]
	[Header("Variables")]
	public int pattern = 0;

	[Space(5f)]
	[Header("Pattern 1")]
	public float lightDistance;
	public float lightTime;
	[Range(0f, 0.99f)]
	public float lightTurnOffTime;
	private float _playerDistance;
	private int _currentLight;

	[Space(5f)]
	[Header("Pattern 2")]
	public float blinkingTime;
	private float _blinkingCounter;
	private bool _lightsOn = true;
	[Range(0f, 1f)]
	public float blinkingIntensity;
	private float _startingIntensity;
	private float _startingBeamIntensity;
	public float blinkingRange;
	private float _startingRange;
	public bool beamBlinks = false;
	public GameObject beamObject;

	void Start () {
		foreach (Light l in lights) {
			_startingIntensity = l.intensity;
			_startingRange = l.range;
			l.intensity = 0f;
		}
		foreach (Renderer lg in lightRenderers) {
			lg.enabled = false;
		}

		beamObject.SetActive(false);
		beamLight.gameObject.SetActive(false);
		_startingBeamIntensity = beamLight.intensity;

		StartCoroutine(LightTiming());
	}
	
	void Update () {
		/*_playerDistance = Vector3.Distance(player.position, transform.position);
		if (_playerDistance <=  lightDistance) {
			foreach (Light l in lights) {
				l.enabled = true;
			}
		}*/
		if (pattern == 1) {
			if (Time.time >= _blinkingCounter) {
				_blinkingCounter = Time.time + blinkingTime;
				_lightsOn = !_lightsOn;

				if (_lightsOn) {
					foreach (Light l in lights) {
						l.intensity = _startingIntensity;
					}
					if (beamBlinks) beamLight.intensity = _startingBeamIntensity;
				} else {
					foreach (Light l in lights) {
						l.intensity = blinkingIntensity * _startingIntensity;
					}
					if (beamBlinks) beamLight.intensity = blinkingIntensity * _startingBeamIntensity;
				}
			}
		}

		if (Input.GetKeyDown(KeyCode.P)) {
			ChangePattern(1);
		}
		if (Input.GetKeyDown(KeyCode.O)) {
			ChangePattern(0);
		}
	}

	IEnumerator LightTiming () {
		yield return new WaitForSeconds(lightTime);
		if (pattern == 0) {
			StartCoroutine(TurnLightOff(_currentLight));
			_currentLight++;
			if (_currentLight >= lightRenderers.Length) _currentLight = 0;
			lightRenderers[_currentLight].enabled = true;
			lights[_currentLight].intensity = _startingIntensity;
		}
		StartCoroutine(LightTiming());
	}

	IEnumerator TurnLightOff (int i) {
		yield return new WaitForSeconds(lightTime * lightTurnOffTime * lightRenderers.Length);
		if (pattern == 0) {
			lightRenderers[i].enabled = false;
			lights[i].intensity = 0f;
		}
	}

	public void ChangePattern (int p) {
		switch(p) {
			case 0: 
				foreach (Light l in lights) {
					l.enabled = true;
					l.intensity = _startingIntensity;
					l.range = _startingRange;
				}
				foreach (Renderer lg in lightRenderers) {
					lg.enabled = false;
				}
				foreach (Light l in lights) {
					l.intensity = 0f;
				}
				beamLight.gameObject.SetActive(false);
				beamObject.SetActive(false);
			break;
			case 1:
				foreach (Light l in lights) {
					l.enabled = true;
					l.range = blinkingRange;
				}
				foreach (Renderer lg in lightRenderers) {
					lg.enabled = true;
				}
				foreach (Light l in lights) {
					l.intensity = _startingIntensity;
				}
				beamLight.gameObject.SetActive(true);
				beamObject.SetActive(true);
			break;
		}

		pattern = p;
	}
}
