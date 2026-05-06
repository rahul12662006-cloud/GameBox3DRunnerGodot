# Phase 5A.8 Character Animation + Pose Polish

Adds imported character pose handling for Quaternius characters:
- tries Skeleton3D bone posing to reduce T-pose
- adds procedural overlay limbs if the imported model has no usable skeleton
- keeps the existing LockedCharacter.tscn pipeline
- improves HUD debug text for character mode
