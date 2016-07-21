jrequire 'org.openscience.cdk.DefaultChemObjectBuilder'
jrequire 'org.openscience.cdk.io.MDLV2000Writer'
jrequire 'org.openscience.cdk.layout.StructureDiagramGenerator'
jrequire 'org.openscience.cdk.smiles.SmilesParser'

jrequire 'java.io.StringWriter'

class MoleculesController < ApplicationController
  include Org::Openscience
  # before_filter :find_all_compounds

  # post function to search for compounds based on SMARTS/SMILES
  # @author woetzens
  def search
    @structure_search_query = params[:structure_search_query]
    # @search=@structure_search_query # used for logging, and logs the origin search query - see ApplicationController#log_event
    @structure_search_query||=""
    @search_type = params.keys.find{|key| Seek::Search::Smiles::TYPES.has_key? key.to_sym}.to_sym
    
    @compounds_hash = []
    
    case @search_type
    when :SMILES
      @canonical_policy = params[:canonical_policy].to_sym
      @isotope_stereo_policy = params[:isotope_stereo_policy].to_sym
      smiles = Seek::Search::Smiles.matchCompoundSmiles( Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash, @structure_search_query, @canonical_policy, @isotope_stereo_policy)
      @compounds_hash = Seek::Data::CompoundsExtraction.get_compounds_hash.keep_if { |key,value| smiles.has_key? key}
    when :SMARTS
      smiles, @matched_atoms_lists = Seek::Search::Smiles.matchCompoundSmarts Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash, @structure_search_query
      @compounds_hash = Seek::Data::CompoundsExtraction.get_compounds_hash.keep_if { |key,value| smiles.has_key? key}
    when :SIMILARITY
      @tanimoto_coefficient_cutoff = params[:tanimoto_coefficient].to_f
      smiles, @coefficients = Seek::Search::Smiles.matchCompoundSimilarity Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash, @structure_search_query, @tanimoto_coefficient_cutoff
      @compounds_hash = Seek::Data::CompoundsExtraction.get_compounds_hash.keep_if { |key,value| smiles.has_key? key}
    else
      @compounds_hash = []
    end
    
    flash.now[:notice] = render_to_string( :partial => 'smiles/search_query').html_safe

    respond_to do |format|
      format.html { render template: 'data_files/compounds_view' }
      # format.xml { render template: 'data_files/compounds_view' }
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

  # used as ajax action for creating a redbox containing a JSME molecular editor
  # @author woetzens
  def jsme_box
    respond_to do |format|
      format.html { render :partial => "molecules/jsme_box",
                           :locals => {}
                  }
    end
  end

  private  

  def find_all_compounds
     @compounds=Compound.order(:name)
  end

end