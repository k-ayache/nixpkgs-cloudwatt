from contrail_api_cli.resource import Resource

d = Resource('domain', fq_name=['default-domain']).fetch()
p = Resource('project', fq_name=['default-domain', 'service'], parent=d)
p.save()
