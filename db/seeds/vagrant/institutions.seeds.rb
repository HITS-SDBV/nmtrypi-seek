Institution.find_or_create_by_title( 'Heidelberg Institute for Theoretical Studies', :country => 'Germany')
Institution.find_or_create_by_title( 'DKFZ - Deutsche Krebs Forschung Zentrum', :country => 'Germany', :city => 'Heidelberg')
Institution.find_or_create_by_title( 'NCI - National Cancer Institute', :country => 'USA', :city => 'Bethesda')
Institution.find_or_create_by_title( 'Max Planck Institute for Biophysical Chemistry', :country => 'Germany', :city => 'Goettingen')
puts "Seeded Institutions"

