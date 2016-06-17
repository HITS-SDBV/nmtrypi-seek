after "vagrant:projects", "vagrant:workgroups" do
  project = Project.find_by_title("Vagrant")
  institution = Institution.find_by_title("Heidelberg Institute for Theoretical Studies")
  workgroup = WorkGroup.find_by_project_id_and_institution_id( project.id, institution.id)

  admin_user = User.find_or_create_by_login(
    :login => 'vagrant',
    :email => 'vagrant@example.com',
    :password => 'vagrant', :password_confirmation => 'vagrant'
  )
  
  admin_user.activate
  admin_user.person ||= Person.create(:first_name => 'Admin', :last_name => 'User', :email => 'vagrant@example.com')
  admin_user.save
  admin_user.person.work_groups << workgroup
  admin_person = admin_user.person

  admin_person.add_roles([['gatekeeper', project],
                          ['project_manager', project]])
  admin_person.save

  puts "Seeded 1 User."
end