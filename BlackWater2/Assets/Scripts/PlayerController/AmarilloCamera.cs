using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AmarilloCamera : MonoBehaviour {
	[Space(5f)]
	[Header("Dependencies")]
	public Transform bodyTransform;
	public Transform cameraTransform;

	[Space(5f)]
	[Header("Variables")]
	public float horizontalSensitivity = 2f;
	public float verticalSensitivity = 2f;
	public float maxVerticalAngle = 90f;
	public float minVerticalAngle = -90f;

	private Vector3 _horizontalVector;
	private Vector3 _verticalVector;

	private bool _unlockCursor;

	void Start () {
		Cursor.visible = false;
		Cursor.lockState = CursorLockMode.Locked;
	}
	
	void Update () {
		if (!_unlockCursor) {
			_horizontalVector.y += Input.GetAxis("Look X") * horizontalSensitivity ;
			_verticalVector.x = Mathf.Clamp(_verticalVector.x, -360, 360);

			_verticalVector.x += -Input.GetAxis ("Look Y") * verticalSensitivity ;
			_verticalVector.x = Mathf.Clamp(_verticalVector.x, minVerticalAngle, maxVerticalAngle);

			bodyTransform.localRotation = Quaternion.Euler(_horizontalVector.x, _horizontalVector.y, _horizontalVector.z);
			cameraTransform.localRotation = Quaternion.Euler (_verticalVector.x, _verticalVector.y, _verticalVector.z);
		}

		if (Input.GetKeyDown(KeyCode.M)) {
			ToggleCursor();
		}
	}

	public void ToggleCursor () {
		_unlockCursor = !_unlockCursor;
		Cursor.visible = !Cursor.visible;
		if (_unlockCursor) Cursor.lockState = CursorLockMode.None;
		else Cursor.lockState = CursorLockMode.Locked;
	}
}
