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
    if Seek::Search::SearchTermStandardize.to_standardize?(value)
      id_smiles_hash =  Seek::Data::CompoundsExtraction.instance.compound_id_smiles_hash
      standardized_value = Seek::Search::SearchTermStandardize.to_standardize(value)
      smiles =  id_smiles_hash[standardized_value]
      smile_graph_link = nil
      if smiles
        graph_url = compound_visualization_path({id: data_id,compound_id: standardized_value})
        smile_graph_link = image_tag_for_key("image", graph_url, 'View graph', {:rel => "lightbox"}, nil)
      end

     search_link = form_tag main_app.search_path, :html => {:style => 'display:inline;'} do
        hidden_field_tag(:search_query, value)  +
        hidden_field_tag(:search_type, "All")  +
        link_to_function(value, "$(this).up('form').submit()") +
        " " +
        smile_graph_link
     end.html_safe

    else
      auto_link(h(value), :html => {:target => "_blank"})
    end
  end
end  