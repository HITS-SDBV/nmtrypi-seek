module SpreadsheetHelper
  
  include Seek::Data::SpreadsheetExplorerRepresentation

  def generate_paginate_rows(rows, sheet_index, per_page)
    #need to record the index of the nil row, for later use
    rows_with_index = []
    rows = rows.drop(1) if rows.first.nil?
    rows.each_with_index do |row, index|
       if row.nil?
         rows_with_index << Row.new(index+1)
       else
         rows_with_index << row
       end
    end

    if sheet_index == params[:sheet].try(:to_i)
      current_page = params[:page].try(:to_i) || 1
    else
      current_page = 1
    end
    WillPaginate::Collection.create(current_page, per_page, rows_with_index.count) do |pager|
      start = (current_page-1)*per_page # assuming current_page is 1 based.
      pager.replace(rows_with_index[start, per_page]) unless rows_with_index[start, per_page].nil?
    end
  end

  def cell_link value, data_file_id
    if Seek::Data::DataMatch.compound_name?(value) # if it is a compound id/name
      compound_link data_file_id, value
    elsif Seek::Data::DataMatch.uniprot_identifier?(value) # if it is an uniprot identifier
      string_or_uniprot_link(value)
    else
      auto_link(h(value), :html => {:target => "_blank"})
    end
  end

  def compound_link data_file_id, value
    id_smiles_hash = Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash
    standardized_value = Seek::Data::DataMatch.standardize_compound_name(value)
    smiles = id_smiles_hash[standardized_value]
    smile_graph_link = compound_structure_link(data_file_id, smiles, standardized_value)
    compound_report_link = link_to "Compound summary report", compound_attributes_view_path(:id => data_file_id, :compound_id => value), {:target => "_blank"}

    # creates context menus with links:
    # a link that on click searches the SEEK for a given compound,
    # a link to smiles graph
    # a link to compound summary report

    search_link = form_tag main_app.search_path, :html => {:style => 'display:inline;'} do
          hidden_field_tag(:search_query, value) +
          hidden_field_tag(:search_type, "All") +
          link_to_function("Search in SEEK", "$(this).up('form').submit()",{:target => "_blank"})
    end.html_safe

    li_search = content_tag(:li, search_link, :class => "dynamic_menu_li").html_safe
    li_smiles_graph = content_tag(:li, ("Compound structure " + smile_graph_link).html_safe, :class => "dynamic_menu_li").html_safe
    li_report = content_tag(:li, compound_report_link, :class => "dynamic_menu_li").html_safe
    link_list = "#{li_search} #{li_smiles_graph} #{li_report}"
    link_to_function(value, {:class => "context_menu_link", :onclick => "$j(this).trigger('context_menu', ['#{link_list}']); return false;"}).html_safe
  end

  def string_or_uniprot_link(value)
    uniprot_url = "http://www.uniprot.org/uniprot/#{value}"
    string_db_url = "http://string-db.org/newstring_cgi/show_network_section.pl?identifier=#{value}"
    li_uniprot =content_tag(:li, "Link to UniProt", :class => "dynamic_menu_li",
                            :onclick => "javascript: window.open('#{uniprot_url.html_safe}', '_blank');").html_safe
    li_string =content_tag(:li, "Link to String DB", :class => "dynamic_menu_li",

                           :onclick => "javascript: window.open('#{string_db_url.html_safe}', '_blank');").html_safe
    #left click
    string_or_uniprot_link = link_to_function value, {:class => "context_menu_link", :onclick => "$j(this).trigger('context_menu', ['#{li_uniprot}'+ '#{li_string}']); return false;"}
    string_or_uniprot_link.html_safe
  end

  def compound_structure_link(data_file_id, smiles, compound_id)
    if smiles # get the smiles
      if smiles == "hidden" # is it hidden?
        # show that it would be there, but is hidden
        html_options = {:class => "disabled", :title => "graph cannot be viewed as smiles is hidden!"}
        graph_url = "#"
      else
        # create the url to the smiles graph
        html_options = {:rel => "lightbox"}
        graph_url = compound_visualization_path({id: data_file_id, compound_id: compound_id})
      end
      # create the actual link
      smile_graph_link = image_tag_for_key("compound_formula", graph_url, 'View graph', html_options, nil)
    else
      # there is no smiles
      smile_graph_link = "<img alt='None' class='none_text'>".html_safe
    end
    smile_graph_link.html_safe
  end


  # make general compounds attributes shown in the compound summary report configurable
  # and also hide the real attribute names in the source code which could be published on github.
  # so change general_compounds_attributes.yml on the production server with real attribute names
  def general_compound_attributes
    filepath = File.join(Rails.root, "config/default_data", "general_compounds_attributes.yml")
    h = YAML.load(File.read(filepath))
    h.values
  end

  def get_attribute_value compound_attributes_hash, compound_attribute
    keyword = compound_attribute.singularize.split(" ").join(".*")
    compound_attributes_hash.values.select { |hash_per_file| hash_per_file.detect { |k, v| v if k.match(/#{keyword}/i) } }.map { |h| h[h.keys.detect { |k| k.match(/#{keyword}/i) }] }.uniq
  end

end  