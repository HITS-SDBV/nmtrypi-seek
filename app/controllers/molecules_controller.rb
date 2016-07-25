jrequire 'org.openscience.cdk.DefaultChemObjectBuilder'
jrequire 'org.openscience.cdk.io.MDLV2000Writer'
jrequire 'org.openscience.cdk.layout.StructureDiagramGenerator'
jrequire 'org.openscience.cdk.smiles.SmilesParser'

jrequire 'java.io.StringWriter'

# class MoleculeController
# this class implements actions to search for molecules (based on smiles or smarts) in all data_files
# @author woetzens
class MoleculesController < ApplicationController
  include Org::Openscience
  # before_filter :find_all_compounds

  # default parameters
  DEFAULT_PARAMS = {
    :structure_search_query => "",
    :search_type => "SMILES",
    :canonical_policy => "canonical",
    :isotope_stereo_policy => "no",
    :tanimoto_coefficient => "0.2"
  }

  # search for compounds based on SMARTS/SMILES
  # the view renders a form, where all parameters for the search can be set; it also renders a tables with the found molecules
  # @author woetzens
  def search
    # parse parameters into class variables
    parse_params params
    @smiles_hash = {}
    
    case @search_type
    when :SMILES
      @smiles_hash = Seek::Search::Smiles.matchCompoundSmiles Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash, @structure_search_query, @canonical_policy, @isotope_stereo_policy
    when :SMARTS
      @smiles_hash, @matched_atoms_lists = Seek::Search::Smiles.matchCompoundSmarts Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash, @structure_search_query
    when :SIMILARITY
      @smiles_hash, @coefficients = Seek::Search::Smiles.matchCompoundSimilarity Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash, @structure_search_query, @tanimoto_coefficient_cutoff
    else
      @smiles_hash = {}
    end
    
  end

  def molfile
    smiles = params[:SMILES]

    # smiles parser to generate atom container from smiles string
    smiles_parser = Cdk::Smiles::SmilesParser.new(Cdk::DefaultChemObjectBuilder.getInstance())

    molecule = smiles_parser.parseSmiles(smiles)

    # add coordinates
    sdg = Cdk::Layout::StructureDiagramGenerator.new()
    sdg.setMolecule(molecule)
    sdg.generateCoordinates()
    layed_out_mol = sdg.getMolecule();

    writer = Java::Io::StringWriter.new()
    molwriter = Cdk::Io::MDLV2000Writer.new(writer)
    molwriter.writeMolecule(layed_out_mol)
        
    render :partial => 'molfile',
           :content_type => "text/plain",
           :locals => { frame: writer.toString().to_s }
  end

  private  

  # set class varibales that are used for search from the params
  def parse_params params
    @structure_search_query      = (params[:structure_search_query]                                         || DEFAULT_PARAMS[:structure_search_query])
    @search_type                 = (params.keys.find{|key| Seek::Search::Smiles::TYPES.has_key? key.to_sym} || DEFAULT_PARAMS[:search_type]           ).to_sym
    @canonical_policy            = (params[:canonical_policy]                                               || DEFAULT_PARAMS[:canonical_policy]      ).to_sym
    @isotope_stereo_policy       = (params[:isotope_stereo_policy]                                          || DEFAULT_PARAMS[:isotope_stereo_policy] ).to_sym
    @tanimoto_coefficient_cutoff = (params[:tanimoto_coefficient]                                           || DEFAULT_PARAMS[:tanimoto_coefficient]  ).to_f
  end

end