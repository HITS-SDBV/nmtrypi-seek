module Seek
  module Data
    class CompoundsExtraction


      # compounds hash
      def self.get_compounds_hash user=User.current_user
        Rails.cache.fetch("#{DataFile.order("updated_at desc").first.cache_key}-#{user.try(:cache_key)}-compounds-hash-all") do
          compounds_hash = {}
          DataFile.all.each do |df|
            compounds_hash.merge!(get_compounds_hash_per_file(df, user)) { |compound_id, attr1, attr2| Hash(attr1).merge(Hash(attr2)) }
          end
          compounds_hash
        end
      end

      def self.get_compounds_hash_per_file(data_file, user=User.current_user)
        Rails.cache.fetch("#{data_file.cache_key}-#{user.try(:cache_key)}-compounds-hash-per-file") do
          compounds_hash = {}
          if data_file.spreadsheet
            begin
              compound_id_sheets = data_file.spreadsheet.sheets.select { |sh| sh.actual_rows.sort_by(&:index)[0].actual_cells.detect { |cell| cell.value.match(/compound/i) } }
            rescue NoMethodError, NameError => e
              compound_id_sheets = nil
            end
            if !compound_id_sheets.blank?
              compound_id_sheets.each do |sheet|
                header_cells = sheet.actual_rows.sort_by(&:index)[0].actual_cells.reject { |cell| cell.value.empty? }
                compound_attributes = []

                header_hash = {}
                header_cells.each do |head_cell|
                  header_hash[head_cell.column] = head_cell.value
                end
                compound_id_cell = header_cells.detect { |cell| cell.value.match(/compound/i) }
                compound_id_column = compound_id_cell.column

                # cell content df.spreadsheet.sheets.first.rows[1].cells[1].value
                sheet.actual_rows.select { |row| row.index > 1 && Seek::Data::DataMatch.compound_name?(row.actual_cells.detect { |cell| cell.column == compound_id_column }.try(:value)) }.each do |row|
                  row_hash = {}
                  row.actual_cells.each do |cell|
                    attr_name = header_hash[cell.column]
                    attr_value = !data_file.can_download?(User.current_user) && cell.column != compound_id_column ? "hidden" : cell.value
                    row_hash[attr_name] = attr_value if !attr_name.blank?
                  end
                  compound_attributes << row_hash
                end
                # get hash
                grouped_attributes_by_compound_id = compound_attributes.group_by { |attr| attr[compound_id_cell.value] }
                grouped_attributes_by_compound_id.each do |id, attr|
                  standardized_compound_id = Seek::Data::DataMatch.standardize_compound_name(id)
                  compounds_hash[standardized_compound_id] = {"#{data_file.id}" => attr.first}#attr.first.select { |attr_name, attr_value| report_attributes?(attr_name) }
                end
              end
            end
          end
          compounds_hash
        end
      end

      def self.get_compound_id_smiles_hash user=User.current_user
        Rails.cache.fetch("#{DataFile.order('updated_at desc').first.cache_key}-#{user.try(:cache_key)}-all-compound-id-smile-hash") do
          id_smiles_hash = {}
          DataFile.all.each do |df|
            id_smiles_hash.merge!(get_compound_id_smiles_hash_per_file(df, user)) { |key, v1, v2| [v1, v2].detect { |v| !v.blank? && v != "hidden" } || v1 }
          end
          #sort by key
          id_smiles_hash.sort_by { |k, v| k.to_s }.to_h
        end
      end

      def self.get_compound_id_smiles_hash_per_file data_file, user=User.current_user
        Rails.cache.fetch("#{data_file.cache_key}-#{user.try(:cache_key)}-compound-id-smile-hash") do
          id_smiles_hash = {}
          #temporiably only excels
          if data_file.content_blob.is_extractable_spreadsheet?
            xml = data_file.spreadsheet_xml
            doc = LibXML::XML::Parser.string(xml).parse
            doc.root.namespaces.default_prefix="ss"
            compound_id_cells = get_column_cells doc, "compound"
            smiles_cells = get_column_cells doc, "smile"
            compound_id_cells.each do |id_cell|
              row_index = id_cell.attributes["row"]
              smile = smiles_cells.detect { |cell| cell.attributes["row"] == row_index }.try(:content)
              if id_cell && Seek::Data::DataMatch.compound_name?(id_cell.content) && !smile.blank?
                standardized_compound_id = Seek::Data::DataMatch.standardize_compound_name(id_cell.content)
                smile_or_hidden = data_file.can_download?(user) ? smile : "hidden"
                id_smiles_hash[standardized_compound_id] = smile_or_hidden
              end
            end
          end
          id_smiles_hash
        end
      end

      def self.clear_cache
        User.all.each do |user|
          Rails.cache.delete("#{DataFile.order("updated_at desc").first.cache_key}-#{user.try(:cache_key)}-compounds-hash-all")
          Rails.cache.delete("#{DataFile.order('updated_at desc').first.cache_key}-#{user.try(:cache_key)}-all-compound-id-smile-hash")

          DataFile.all.each do |df|
            Rails.cache.delete("#{data_file.cache_key}-#{user.try(:cache_key)}-compounds-hash-per-file")
            Rails.cache.delete("#{df.cache_key}-#{user.try(:cache_key)}-compound-id-smile-hash")
          end
        end
      end

      private
      def self.get_column_cells doc, column_name
        head_cells = doc.find("//ss:sheet[@hidden='false' and @very_hidden='false']/ss:rows/ss:row/ss:cell").find_all { |cell| cell.content.gsub(/\s+/, " ").strip.match(/#{column_name}/i) }
        body_cells = []
        unless head_cells.blank?
          head_cell = head_cells[0]
          head_col = head_cell.attributes["column"]
          body_cells = doc.find("//ss:sheet[@hidden='false' and @very_hidden='false']/ss:rows/ss:row/ss:cell[@column=#{head_col} and @row != 1]").find_all { |cell| !cell.content.blank? }
        end
        body_cells
      end

    end
  end
end