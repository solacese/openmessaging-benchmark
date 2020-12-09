[ha_sol_primary_nodes]
${solace-primary-ip}

[ha_sol_primary_privateip]
${solace-primary-privateip}

[ha_sol_backup_nodes]
${solace-backup-ip}

[ha_sol_backup_privateip]
${solace-backup-privateip}

[ha_sol_monitor_nodes]
${solace-monitor-ip}

[ha_sol_monitor_privateip]
${solace-monitor-privateip}

[prometheus]
%{ for ip in prometheus-ips ~}
${ip}
%{ endfor ~}

[sol_brokers:children]
ha_sol_primary_nodes
ha_sol_backup_nodes
ha_sol_monitor_nodes

[sol_brokers_privateip:children]
ha_sol_primary_privateip
ha_sol_backup_privateip
ha_sol_monitor_privateip
