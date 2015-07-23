module Seek
  module Data
    class CompoundsExtraction

      def self.get_compound_id_smiles_hash user=User.current_user
        Rails.cache.fetch("#{DataFile.order('updated_at desc').first.cache_key}-#{user.try(:cache_key)}-all-compound-id-smile-hash") do
          id_smiles_hash = {}
          DataFile.all.each do |df|
            id_smiles_hash.merge!(get_compound_id_smiles_hash_per_file(df, user)){ |key, v1, v2| [v1,v2].detect{|v| !v.blank? && v != "hidden"} || v1  }
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
              if id_cell && is_standard_compound_id?(id_cell.content) && !smile.blank?
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
          Rails.cache.delete("#{DataFile.order('updated_at desc').first.cache_key}-#{user.try(:cache_key)}-all-compound-id-smile-hash")
          DataFile.all.each do |df|
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

      def self.is_standard_compound_id? content
        Seek::Data::DataMatch.compound_name?(content)
      end
    end
  end
end