require 'seek/external_search'

module SearchHelper
  include Seek::ExternalSearch
  def search_type_options
    search_type_options = ["All"] | Seek::Util.searchable_types.collect{|c| [(c.name.underscore.humanize == "Sop" ? t('sop') : c.name.underscore.humanize.pluralize),c.name.underscore.pluralize] }
    return search_type_options
  end
    
  def saved_search_image_tag saved_search
    tiny_image = image_tag "famfamfam_silk/find.png", :style => "padding: 11px; border:1px solid #CCBB99;background-color:#FFFFFF;"
    return link_to_draggable(tiny_image, saved_search_path(saved_search.id), :title=>tooltip_title_attrib("Search: #{saved_search.search_query} (#{saved_search.search_type})"),:class=>"saved_search", :id=>"sav_#{saved_search.id}")
  end

  def force_search_type search_type_options
    search_type_options.each do |type|
      if current_page?("/"+type[1].to_s)
        @search_type=type[1].to_s
      end
    end
  end

  def external_search_tooltip_text

    text = "Checking this box allows external resources to be includes in the search.<br/>"
    text << "External resources include: "
    text << search_adaptor_names.collect{|name| "<b>#{name}</b>"}.join(",")
    text << "<br/>"
    text << "This means the search will take longer, but will include results from other sites"
    text.html_safe
  end
  def get_resource_hash scale, external_resource_hash
    internal_resource_hash = {}
    if external_resource_hash.blank?
      @results_scaled[scale].each do |item|
        tab = item.respond_to?(:tab) ? item.tab : item.class.name
        if item.respond_to?(:is_external_search_result?) && item.is_external_search_result?
          external_resource_hash[tab] = [] unless external_resource_hash[tab]
          external_resource_hash[tab] << item
        else
          internal_resource_hash[tab] = [] unless internal_resource_hash[tab]
          internal_resource_hash[tab] << item
        end
      end
    else
      @results_scaled[scale].each do |item|
        tab = item.respond_to?(:tab) ? item.tab : item.class.name
        unless item.respond_to?(:is_external_search_result?) && item.is_external_search_result?
          internal_resource_hash[tab] = [] unless internal_resource_hash[tab]
          internal_resource_hash[tab] << item
        end
      end
    end
    [internal_resource_hash, external_resource_hash]
  end

  def search_extractable_items items, search_query

    sheet_array = []
    items = items.select { |item| item.is_asset? && item.content_blob.is_extractable_spreadsheet? }
    results = items.select do |object|
      workbook = Rails.cache.fetch(object.content_blob.cache_key) do
        object.spreadsheet
      end
      xml = object.spreadsheet_xml
      doc = LibXML::XML::Parser.string(xml).parse
      doc.root.namespaces.default_prefix="ss"

      #@origin_query = "Final Concentration,  LmPTR1 <=  30"
      # @origin_query  ="Final Concentration, LmPTR1 [µM]"
      search_query = search_query ? search_query.gsub(/\s+/, " ").strip : ""
      operators = ["<", "<=", ">", ">=", "="]
      search_operator = operators.select { |o| search_query.index(o) }.max_by(&:length)
      if search_operator
        search_arr = search_query.split(search_operator)
        search_field_name = search_arr.first
        search_value = search_arr.last
        search_operator = "=" if search_field_name == search_value

        head_cells = doc.find("//ss:sheet[@hidden='false' and @very_hidden='false']/ss:rows/ss:row/ss:cell").find_all { |cell| cell.content.gsub(/\s+/, " ").strip.match(/#{search_field_name}/i) }
        unless head_cells.blank?
          head_cell = head_cells[0]
          #head_sheet = head_cell.parent.parent.parent
          head_col = head_cell.attributes["column"]
          cells = doc.find("//ss:sheet[@hidden='false' and @very_hidden='false']/ss:rows/ss:row/ss:cell[@column=#{head_col}][text() #{search_operator} #{search_value}]").find_all

        end
      else
        standardized_underscore_search_query = Seek::Search::SearchTermStandardize.to_standardize(search_query).underscore
        cells = doc.find("//ss:sheet[@hidden='false' and @very_hidden='false']/ss:rows/ss:row/ss:cell").find_all { |cell| Seek::Search::SearchTermStandardize.to_standardize(cell.content).underscore.include? standardized_underscore_search_query }
      end
      unless cells.blank?
        cell_groups = cells.group_by { |c| c.parent.try(:parent).try(:parent).try(:attributes).to_h["name"] }
        sheet_array |= cell_groups.map do |sheet_name, match_cells|
          sheet = workbook.sheets.detect { |sh| sheet_name.downcase == sh.name.downcase }
          rows_nums = match_cells.map { |c| c.attributes["row"].to_i }
          col_nums = match_cells.map { |c| c.attributes["column"].to_i }
          [sheet, rows_nums, col_nums, object.id]
        end
      end
      !sheet_array.empty?
    end
    return results, sheet_array
  end
end
