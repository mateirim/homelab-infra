# site.pp

# Default file resource settings
File { backup => false }

# Default node definition
node default {
  # Include the role class based on Hiera data
  # The 'role' key will be looked up in the Hiera hierarchy
  # We use 'unique' merge to allow multiple roles to be defined across different levels
  $roles = lookup('role', Array[String], 'unique', ['role::default'])
  
  if ! $roles.empty {
    include $roles
  }
}
