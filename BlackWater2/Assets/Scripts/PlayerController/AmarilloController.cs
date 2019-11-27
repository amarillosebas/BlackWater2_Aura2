using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AmarilloController : MonoBehaviour {
	[Space(5f)]
	[Header("Dependencies")]
	public CharacterController controller;
	public Transform camera;

	[Space(5f)]
	[Header("Movement")]
	public float moveSpeed = 6f;
	public float runSpeed = 9;
	public float backwardSpeed = 0.5f;
	private float _inputX;
	private float _inputY;
	private bool _halfSpeed;
	private Vector3 _movementVector;
	private float _tempX;
	private float _tempY;
	private float _tempZ;

	[Space(5f)]
	[Header("Jump")]
	public float jumpSpeed = 10;
	public float gravity = 0.5f;
	private float _tempJumpSpeed;
	private float _jumpTime;

	[Space(5f)]
	[Header("Crouch")]
	public float crouchSpeed = 3;
	public float crouchHeight = 0.5f;
	public float crouchRadius = 0.25f;
	private float _controllerStartingRadius;
	private float _controllerStartingHeight;
	private float _cameraStartingHeight;
	private RaycastHit _crouchHeadCheck;
	private bool _crouchingBlocked;
	private Vector3 _cameraVector;

	[Space(5f)]
	[Header("Water")]
	public bool onWater = false;
	public float jumpIntervalOnWater = 0.3f;
	private float _waterJumpCounter = 0f;

	void Start () {
		_controllerStartingRadius = controller.radius;
		_controllerStartingHeight = controller.height;
		_cameraStartingHeight = camera.localPosition.y;
	}
	
	void Update () {
		_inputX = Input.GetAxis("Horizontal");
		_inputY = Input.GetAxis ("Vertical");

		if ((_inputY > 0.1 || _inputY < -0.1) && (_inputX > 0.1 || _inputX < -0.1)) {
			_halfSpeed = true;
		} else _halfSpeed = false;

		if (!onWater) {
			if (Input.GetButtonDown("Jump") && controller.isGrounded) {
				_tempJumpSpeed = jumpSpeed;
			}
		} else {
			if (Input.GetButtonDown("Jump")) {
				if (Time.time > _waterJumpCounter) {
					_waterJumpCounter = Time.time + jumpIntervalOnWater;
					_tempJumpSpeed = jumpSpeed;
				}
			}
		}

		if (Physics.Raycast (controller.transform.position, controller.transform.up, out _crouchHeadCheck)) {
			if (_crouchHeadCheck.distance <= _controllerStartingHeight * 0.5f) {
				_crouchingBlocked = true;
			} 
			if (_crouchHeadCheck.distance > _controllerStartingHeight * 0.52f || _crouchHeadCheck.transform == null) {
				_crouchingBlocked = false;
			}
		} else {
			_crouchingBlocked = false;
		}

		if ((Input.GetButton("Crouch") || _crouchingBlocked) && controller.isGrounded) {
			_cameraVector = new Vector3 (camera.localPosition.x, _cameraStartingHeight * 0.49f, camera.localPosition.z);
			camera.localPosition = _cameraVector;
			controller.height = crouchHeight;
			controller.radius = crouchRadius;
		}
		if (!Input.GetButton("Crouch") && !_crouchingBlocked) {
			_cameraVector = new Vector3 (camera.localPosition.x, _cameraStartingHeight, camera.localPosition.z);
			camera.localPosition = _cameraVector;
			controller.height = _controllerStartingHeight;
			controller.radius = _controllerStartingRadius;
		}
	}

	void FixedUpdate () {
		_movementVector = Vector3.zero;
		float backwardFactor = 1;
		if (_inputY < 0) backwardFactor = backwardSpeed;

		if (!Input.GetButton("Crouch") && !_crouchingBlocked && !Input.GetButton("Run")) {
			_tempX = moveSpeed * Time.fixedDeltaTime * _inputX * backwardFactor;
			_tempZ = moveSpeed * Time.fixedDeltaTime * _inputY * backwardFactor;
		}
		if (!Input.GetButton ("Crouch") && !_crouchingBlocked  && Input.GetButton("Run")) {
			if (_inputX >= 0) {
				_tempX = runSpeed * Time.fixedDeltaTime * _inputX;
				_tempZ = runSpeed * Time.fixedDeltaTime * _inputY;
			} else {
				_tempX = moveSpeed * Time.fixedDeltaTime * _inputX * backwardFactor;
				_tempZ = moveSpeed * Time.fixedDeltaTime * _inputY * backwardFactor;
			}
		}
		if (Input.GetButton("Crouch") || _crouchingBlocked) {
			_tempX = crouchSpeed * Time.fixedDeltaTime * _inputX;  
			_tempZ = crouchSpeed * Time.fixedDeltaTime * _inputY * backwardFactor;
		}

		if(Physics.Raycast(controller.transform.position, controller.transform.up, controller.height *0.49f )) {
			_tempJumpSpeed = 0;
		}

		_tempJumpSpeed -= gravity;
		_tempY = Time.fixedDeltaTime * _tempJumpSpeed;

		if (!_halfSpeed) _movementVector = new Vector3 (_tempX, _tempY, _tempZ);
		else _movementVector = new Vector3 (_tempX * 0.707106682f, _tempY, _tempZ * 0.707106682f);

		_movementVector = controller.transform.TransformDirection(_movementVector); 
		controller.Move(_movementVector);
	}
}
