module Seek
  module Data
    class DataMatch
      def self.compound_name? content
        # nmtrypi project compounds naming conventions, e.g. NMT-H0004
        #content.to_s.downcase.match(/\Anmt[-_][a-zA-Z]+(\d+)\Z/i) != nil
        content.to_s.match(/nmt[-_][a-zA-Z]+\d+/i) != nil
      end

      def self.get_compound_name content
        # nmtrypi project compounds naming conventions, e.g. NMT-H0004
        #content.to_s.downcase.match(/\Anmt[-_][a-zA-Z]+(\d+)\Z/i) != nil
        content.to_s.match(/nmt[-_][a-zA-Z]+\d+/i)
      end

      def self.standardize_compound_name content
        # "-" <--> "_", and remove leading 0s before the non-zero number, e.g. NMT-H0004 <--> NMT_H4
        if compound_name? content
          #content.match(/nmt[-_][a-zA-Z]+\d+/i)
          content.sub(/nmt[-_][a-zA-Z]+\d+/i) do |val|
            val.downcase.split(/(\d+)/).map { |splitted_val| (splitted_val.split("").uniq.join("").to_i != 0) ? splitted_val.sub(/^0+/, "") : splitted_val }.join("").underscore
          end
        else
          content
        end
      end

      def self.uniprot_identifier? content
        content.to_s.match(/\A([OPQ][0-9][A-Z0-9]{3}[0-9]|[A-NR-Z][0-9]([A-Z][A-Z0-9]{2}[0-9]){1,2})\z/i) !=nil
      end

    end

  end
end