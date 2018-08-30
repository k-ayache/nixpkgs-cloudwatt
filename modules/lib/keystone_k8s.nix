{ pkgs }:

with pkgs.lib;
with builtins;

let

  createProjectUserRole = project: user: roles:
    concatStringsSep "\n" (map (role: ''
      openstack role add --project ${project} --user ${user} ${role}
    '') roles);

  createProjectUsers = project: users:
    concatStringsSep "\n" (mapAttrsToList (user: { password, roles ? [] }: ''
      openstack user create --password '${password}' ${user}
    '' + optionalString (roles != []) (createProjectUserRole project user roles)) users);

  createProject = project: { users ? {} }: ''
    openstack project create ${project}
  '' + optionalString (users != {}) (createProjectUsers project users);

in {

  createProjects = projects:
    concatStringsSep "\n" (mapAttrsToList createProject projects);

  createCatalog = catalog: region:
    concatStringsSep "\n" (mapAttrsToList (type: { name, admin_url, internal_url, public_url }: ''
      openstack service create --description "${type} service" --name ${name} ${type}
      openstack endpoint create --region ${region} --adminurl "${admin_url}" --internalurl "${internal_url}" \
        --publicurl "${public_url}" ${type}
    '') catalog);

  createRoles = roles:
    concatStringsSep "\n" (map (role: ''
      openstack role create ${role}
    '') roles);

}
