using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class AmarilloWaterPhysics : MonoBehaviour {
	[Space(5f)]
	[Header("Dependencies")]
	public AmarilloController playerController;

	[Space(5f)]
	[Header("Variables")]
	private float _playerGravity;
	public float playerGravityOnWater = 0.05f;
	private float _playerJumpSpeed;
	public float playerJumpSpeedOnWater = 2f;

	void OnTriggerEnter (Collider c) {
		if (c.tag == "WaterPhysics") {
			playerController.onWater = true;
			_playerJumpSpeed = playerController.jumpSpeed;
			playerController.jumpSpeed = playerJumpSpeedOnWater;
			_playerGravity = playerController.gravity;
			playerController.gravity = playerGravityOnWater;
		}
	}
	void OnTriggerStay (Collider c) {
		if (c.tag == "WaterPhysics") {
			playerController.onWater = true;
		}
	}
	void OnTriggerExit (Collider c) {
		if (c.tag == "WaterPhysics") {
			playerController.onWater = false;
			playerController.jumpSpeed = _playerJumpSpeed;
			playerController.gravity = _playerGravity;
		}
	}
}
