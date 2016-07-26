jrequire 'org.openscience.cdk.DefaultChemObjectBuilder'
jrequire 'org.openscience.cdk.smiles.SmilesParser'
jrequire 'org.openscience.cdk.smiles.SmilesGenerator'
jrequire 'org.openscience.cdk.smiles.smarts.SMARTSQueryTool'
jrequire 'org.openscience.cdk.similarity.Tanimoto'
jrequire 'org.openscience.cdk.fingerprint.Fingerprinter'
jrequire 'org.openscience.cdk.tools.manipulator.AtomContainerManipulator'
jrequire 'org.openscience.cdk.tools.CDKHydrogenAdder'

module Seek
  module Search
    # @author woetzens
    # @date 07/15/2016
    class Smiles
      include Org::Openscience
      include Java

      TYPES = Hash.new{ |hash, key| raise( "Search Type #{ key } is unknown" )}.update(
        :SMILES => "Search for Structure",
        :SMARTS => "Search for Substructure",
        :SIMILARITY => "Search for similar Structures"
      )

      FLAVOURS = Hash.new{ |hash, key| raise( "SMILES Flavour #{ key } is unknown" )}.update(
        :generic  => "non-canonical SMILES string, different atom ordering produces different SMILES. No isotope or stereochemistry encoded.",
        :unique   => "canonical SMILES string, different atom ordering produces the same* SMILES. No isotope or stereochemistry encoded.",
        :isomeric => "non-canonical SMILES string, different atom ordering produces different SMILES. Isotope and stereochemistry is encoded.",
        :absolute => "canonical SMILES string, different atom ordering produces the same SMILES. Isotope and stereochemistry is encoded."
      )
      # * the unique SMILES generation uses a fast equitable labelling procedure and as such there are some structures which may not be unique. The number of such structures is generally minimal.

      POLICY_CANONICAL = Hash.new{ |hash, key| raise( "SMILES Canonical Policy #{ key } is unknown" )}.update(
        :canonical => "canonical SMILES string, different atom ordering produces the same SMILES.",
        :non_canonical => "non-canonical SMILES string, different atom ordering produces different SMILES."
      )

      POLICY_ISOTOPE_STEREOCHEMISTRY = Hash.new{ |hash, key| raise( "SMILES Isotop or Stereochemsitry Policy #{ key } is unknown" )}.update(
        :no => "No isotope or stereochemistry encoded.",
        :yes => "Isotope and stereochemistry is encoded."
      )

      FLAVOUR_FROM_CANONICAL_AND_ISOTOPE_STEREOCHEMISTRY = {
        :canonical => { :no => :unique,
                        :yes => :absolute},
        :non_canonical => { :no => :generic,
                            :yes => :absolute}
      }

      # class variables that are reused
      @@chem_object_builder = Cdk::DefaultChemObjectBuilder.getInstance()
      @@smiles_parser       = Cdk::Smiles::SmilesParser.new(@@chem_object_builder)

      # in a hash {"compound_id" => "smiles"} search for all key value pairs, that have a matching smiles_query
      # @param compound_smiles_hash hash {"compound_id" => "smiles"}
      # @param smiles_query the smiles string to compare to
      # @param canonical_policy
      # @param isotope_stereo_policy
      # @see http://cdk.github.io/cdk/1.5/docs/api/org/openscience/cdk/smiles/SmilesGenerator.html
      # @return hash {"compound_id" => "smiles"} where the smiles in the hash mathches given the flavor
      def self.matchCompoundSmiles compound_smiles_hash, smiles_query, canonical_policy, isotope_stereo_policy
        matching_compounds_hash = Hash.new()
        smiles_query_molecule = nil

        # exeptions for the query should be handled upstream, since they might be shown as error to the user
        # begin
          # moelcule from query
          smiles_query_molecule = @@smiles_parser.parseSmiles(smiles_query)
        # rescue
          # Rails.logger.error "unable to parse smiles query into molecule: #{smiles_query}"
          # return matching_compounds_hash
        # end

        # smiles generator to generate smiles from atom container
        smiles_generator = smilesGeneratorFromPolicies canonical_policy, isotope_stereo_policy

        # create canonical or non-canonical smiles_query
        smiles_query_normalized = smiles_generator.create(smiles_query_molecule)

        compound_smiles_hash.each do |id,compound_smiles|
          # parse smiles into molecule, skip if not possible
          compound_smiles_molecule = nil
          begin
            compound_smiles_molecule = @@smiles_parser.parseSmiles(compound_smiles)
          rescue
            Rails.logger.warn "unable to parse smiles into molecule or fingerprint: #{compound_smiles} => Skipping"
            next
          end
          compound_smiles_normalized = smiles_generator.create(compound_smiles_molecule)
          if smiles_query_normalized == compound_smiles_normalized
            matching_compounds_hash.merge! id => compound_smiles
          end
        end
        return matching_compounds_hash
      end

      # in a hash {"compound_id" => "smiles"} search for all key value pairs, that have a smarts_query as a substructure
      # @param compound_smiles_hash hash {"compound_id" => "smiles"}
      # @param smarts_query the smiles or amarts string to compare to
      # @return hash {"compound_id" => "smiles"} where the query is a substructure of the molecule, list of lists of matched atom_ids
      def self.matchCompoundSmarts compound_smiles_hash, smarts_query
        matching_compounds_hash = Hash.new()
        matched_atoms_lists = Hash.new()
        smarts_query_tool = nil

        # exeptions for the query should be handled upstream, since they might be shown as error to the user
        # begin
          smarts_query_tool = Cdk::Smiles::Smarts::SMARTSQueryTool.new(smarts_query,@@chem_object_builder)
        # rescue
          # Rails.logger.error "unable to parse smarts query into smarts query tool: #{smarts_query}"
          # return matching_compounds_hash, matched_atoms_lists
        # end

        compound_smiles_hash.each do |id,compound_smiles|
          # TODO it might be necessary to remove stereo-configuration in case isotope_stereo_policy is :no
          # this is not supported yet http://cdk.github.io/cdk/1.5/docs/api/org/openscience/cdk/smiles/smarts/SMARTSQueryTool.html
          compound_smiles_molecule = nil
          begin
            compound_smiles_molecule = @@smiles_parser.parseSmiles(compound_smiles)
          rescue
            Rails.logger.warn "unable to parse smiles into molecule or fingerprint: #{compound_smiles} => Skipping"
            next
          end
          
          # check if it matches
          if smarts_query_tool.matches(compound_smiles_molecule)
            matching_compounds_hash.merge! id => compound_smiles
            matched_atoms_lists.merge! id => smarts_query_tool.getUniqueMatchingAtoms().toArray().collect{ |atom_list| atom_list.toArray().collect{ |i| i.intValue().to_i + 1 } }
          end
        end
        return matching_compounds_hash, matched_atoms_lists
      end

      # in a hash {"compound_id" => "smiles"} search for all key value pairs, that have a smiles molecule that is similar above the tanimoto_coefficient_cutoff
      # @param compound_smiles_hash hash {"compound_id" => "smiles"}
      # @param smiles_query the smiles string for the moelcule the similarity is measured against
      # @param fingerprint_size the size of the fingerprint
      # @param fingerprint_search_depth the depth of the search to generate the fingerprint
      # @param tanimoto_coefficient_cutoff the minimal similarity [0..1] to include the smiles in the result hash
      # @return hash {"compound_id" => "smiles"} where the query structure is similar above the given cutoff, Hash of coefficients {"compound_id" => "tanimoto_coefficient"}
      def self.matchCompoundSimilarity compound_smiles_hash, smiles_query, fingerprint_size, fingerprint_search_depth, tanimoto_coefficient_cutoff
        matching_compounds_hash = Hash.new
        coefficients = Hash.new()

        # create a fingerprinter
        finger_printer = Cdk::Fingerprint::Fingerprinter.new(fingerprint_size,fingerprint_search_depth)

        smiles_query_molecule = nil
        query_molecule_fingerprint = nil
        # exeptions for the query should be handled upstream, since they might be shown as error to the user
        # begin
          smiles_query_molecule = @@smiles_parser.parseSmiles(smiles_query)
          # query_molecule_complete = addHydrogens smiles_query_molecule
          query_molecule_fingerprint = finger_printer.getBitFingerprint(smiles_query_molecule)
        # rescue
          # Rails.logger.error "unable to parse smiles query into molecule or fingerprint: #{smiles_query}"
          # return matching_compounds_hash, coefficients
        # end

        # compare to each molecule
        compound_smiles_hash.each do |id,compound_smiles|
          compound_smiles_molecule = nil
          begin
            compound_smiles_molecule = @@smiles_parser.parseSmiles(compound_smiles)
            # compound_molecule_complete = addHydrogens compound_smiles_molecule
            compound_molecule_fingerprint = finger_printer.getBitFingerprint(compound_smiles_molecule)
          rescue
            Rails.logger.warn "unable to parse smiles into molecule or fingerprint: #{compound_smiles} => Skipping"
            next
          end

          # calculate the similarity
          tanimoto_coeff = Cdk::Similarity::Tanimoto.calculate(query_molecule_fingerprint,compound_molecule_fingerprint)

          # only add if above cutoff
          if tanimoto_coeff > tanimoto_coefficient_cutoff
            matching_compounds_hash.merge! id => compound_smiles
            coefficients.merge! id => tanimoto_coeff
          end
        end
        return matching_compounds_hash, coefficients
      end

      private

      def self.smilesGeneratorFromPolicies canonical_policy, isotope_stereo_policy
        # smiles generator to generate smiles from atom container
        smiles_generator = nil
        
        flavour = FLAVOUR_FROM_CANONICAL_AND_ISOTOPE_STEREOCHEMISTRY[canonical_policy][isotope_stereo_policy]
        case flavour
        when :generic
          smiles_generator = Cdk::Smiles::SmilesGenerator.generic().aromatic()
        when :unique
          smiles_generator = Cdk::Smiles::SmilesGenerator.unique().aromatic()
        when :isomeric
          smiles_generator = Cdk::Smiles::SmilesGenerator.isomeric().aromatic()
        when :absolute
          smiles_generator = Cdk::Smiles::SmilesGenerator.absolute().aromatic()
        else
          smiles_generator = Cdk::Smiles::SmilesGenerator.new
        end

        return smiles_generator
      end
      
      # http://efficientbits.blogspot.de/2013/12/new-smiles-behaviour-parsing-cdk-154.html
      def self.addHydrogens molecule
        adder = Cdk::Tools::CDKHydrogenAdder.getInstance(@@chem_object_builder)
        Cdk::Tools::Manipulator::AtomContainerManipulator.percieveAtomTypesAndConfigureAtoms(molecule);
        adder.addImplicitHydrogens(molecule)
        return molecule
      end
      
    end # class Smiles
  end # module Search
end # modlue Seek