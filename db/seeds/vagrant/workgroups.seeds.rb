after "vagrant:projects", "vagrant:institutions" do
  project = Project.find_by_title("Vagrant")
  institution = Institution.find_by_title("Heidelberg Institute for Theoretical Studies")
  
  WorkGroup.find_or_create_by_project_id_and_institution_id( project.id, institution.id)
end
puts "Seeded 1 workgroup."