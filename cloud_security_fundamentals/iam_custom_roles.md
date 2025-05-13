# IAM Custom Roles

## Overview
- Cloud IAM manages resource permissions through roles rather than direct permissions
- Roles bundle multiple permissions together
- Enables mapping job functions to groups and roles
- Follows principle of least privilege

## Types of Roles
1. **Predefined Roles**
   - Created and maintained by Google
   - Automatically updated with new features/services
   - Example: Editor, Viewer roles

2. **Custom Roles**
   - User-defined roles
   - Bundle specific permissions to meet organizational needs
   - Not automatically updated by Google
   - Created at organization or project level (not folder level)

## Permission Structure
- Format: `<service>.<resource>.<verb>`
- Examples:
  - `compute.instances.list`: List Compute Engine instances
  - `compute.instances.stop`: Stop a VM instance

## Key Operations

### 1. Creating Custom Roles
- Can be created using:
  - YAML file
  - Command-line flags
- Must specify:
  - Role ID
  - Title
  - Description
  - Permissions
  - Stage (ALPHA, BETA, GA, DISABLED)

### 2. Updating Custom Roles
- Methods:
  - YAML file update
  - Command-line flags:
    - `--add-permissions`: Add new permissions
    - `--remove-permissions`: Remove existing permissions
    - `--permissions`: Replace entire permissions list

### 3. Managing Role Lifecycle
- **Disable Role**:
  - Sets stage to DISABLED
  - Inactivates policy bindings
  - Permissions not granted even if role is assigned

- **Delete Role**:
  - Role becomes inactive
  - Cannot create new IAM policy bindings
  - Existing bindings remain but become inactive
  - 7-day window for restoration
  - After 7 days: 30-day permanent deletion process
  - After 37 days: Role ID becomes available again

- **Restore Role**:
  - Available within 7-day window
  - Role starts in DISABLED state
  - Must update stage to make available again

## Best Practices
1. Follow principle of least privilege
2. Use predefined roles when possible
3. Create custom roles only when necessary
4. Document role purposes and permissions
5. Regularly review and update custom roles
6. Use deprecation process for role phase-out:
   - Set role.stage to DEPRECATED
   - Include deprecation_message
   - Specify alternative roles

## Important Considerations
- Custom roles require maintenance
- New permissions/features won't automatically update custom roles
- Role deletion has a 7-day grace period
- Disabled roles don't grant permissions even if assigned
- Role IDs can be reused after 37 days from deletion
