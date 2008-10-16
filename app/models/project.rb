class Project < ActiveRecord::Base
  has_many :work_groups
  has_many :institutions, :through=>:work_groups
  
  def institutions=(new_institutions)
    puts("New institutions = " + new_institutions.to_s)
    new_institutions.each_index do |i|
      new_institutions[i]=Institution.find(new_institutions[i]) unless new_institutions.is_a?(Institution)
    end
    work_groups.each do |wg|
      wg.destroy unless new_institutions.include?(wg.institution)
    end
    for institution in new_institutions
      institutions << institution unless institutions.include?(institution)
    end
  end
end
