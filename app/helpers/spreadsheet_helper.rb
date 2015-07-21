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

  def cell_link value, data_id
    if Seek::Data::DataMatch.compound_name?(value) # if it is a compound id/name
      id_smiles_hash =  Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash
      standardized_value = Seek::Data::DataMatch.standardize_compound_name(value)
      smiles =  id_smiles_hash[standardized_value]
      if smiles # get the smiles
        if smiles == "hidden" # is it hidden?
          # show that it would be there, but is hidden
          html_options =  { :class => "disabled",:title=> "graph cannot be viewed as smiles is hidden!"}
          graph_url = "#"
        else
          # create the url to the smiles graph
          html_options =  {:rel => "lightbox"}
          graph_url = compound_visualization_path({id: data_id,compound_id: standardized_value})
        end
        # create the actual link
        smile_graph_link = image_tag_for_key("compound_formula", graph_url, 'View graph',html_options, nil)
      else
        # there is no smiles
        smile_graph_link = "<img alt='None' class='none_text'>".html_safe
      end
     full_info_link = link_to_remote_redbox("summary report",
                                            { :url => compound_attributes_view_path(:id => data_id, :compound_id => value),
                                              :failure => "alert('Sorry, an error has occurred.'); RedBox.close();",
                                              :method => :get
                                            },
                                            {:id => "compound_attributes_view"
                                            })

      # the following code creates:
      # a link that on click searches the SEEK for a given compound,
      # a link to smiles graph
      # a link to compound summary report

     form_tag main_app.search_path, :html => {:style => 'display:inline;'} do
        hidden_field_tag(:search_query, value)  +
        hidden_field_tag(:search_type, "All")  +
        #link_to_function(image_tag(assets_path("famfamfam_silk/zoom.png")), "$(this).up('form').submit()") #+
        image_tag_for_key("show","$(this).up('form').submit()" , "search compound #{value}", nil, nil, :function) +
         " " +
         smile_graph_link + full_info_link
     end.html_safe
    elsif Seek::Data::DataMatch.uniprot_identifier?(value) # if it is an uniprot identifier
      uniprot_url = "http://www.uniprot.org/uniprot/#{value}"
      string_db_url = "http://string-db.org/newstring_cgi/show_network_section.pl?identifier=#{value}"
      li_uniprot =content_tag(:li, "Link to UniProt",:class => "dynamic_menu_li",
                              :onclick=> "javascript: window.open('#{uniprot_url.html_safe}', '_blank');").html_safe
      li_string =content_tag(:li, "Link to String DB",:class => "dynamic_menu_li",

                              :onclick=> "javascript: window.open('#{string_db_url.html_safe}', '_blank');").html_safe
      ## right click
      #string_or_uniprot_link = link_to_function value, {:class => "uniprot_link", :oncontextmenu=> "$j(this).trigger('context_menu', ['#{li_uniprot}'+ '#{li_string}']); return false;"}
      #left click
      string_or_uniprot_link = link_to_function value, {:class => "uniprot_link", :onclick=> "$j(this).trigger('context_menu', ['#{li_uniprot}'+ '#{li_string}']); return false;"}
      string_or_uniprot_link.html_safe
    else
      auto_link(h(value), :html => {:target => "_blank"})
    end
  end
end  