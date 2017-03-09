jrequire 'org.openscience.cdk.DefaultChemObjectBuilder'
jrequire 'org.openscience.cdk.io.MDLV2000Writer'
jrequire 'org.openscience.cdk.layout.StructureDiagramGenerator'
jrequire 'org.openscience.cdk.smiles.SmilesParser'
jrequire 'org.openscience.cdk.fingerprint.Fingerprinter'
jrequire 'org.openscience.cdk.smiles.smarts.parser.SMARTSParser'

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
    :fingerprint_size => Cdk::Fingerprint::Fingerprinter.DEFAULT_SIZE.to_s,
    :fingerprint_search_depth => Cdk::Fingerprint::Fingerprinter.DEFAULT_SEARCH_DEPTH.to_s,
    :tanimoto_coefficient_cutoff => "0.2"
  }

  # search for compounds based on SMARTS/SMILES
  # the view renders a form, where all parameters for the search can be set; it also renders a tables with the found molecules
  # @author woetzens
  def search
    # parse parameters into class variables
    parse_params params
    @smiles_hash = {}
    
    @compound_id_smiles_hash = Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash
    @visible_compound_id_smiles_hash = @compound_id_smiles_hash.keep_if{ |compound_id,smiles| smiles != 'hidden'}
    
    case @search_type
    when :SMILES
      begin
        @smiles_hash = Seek::Search::Smiles.matchCompoundSmiles @visible_compound_id_smiles_hash, @structure_search_query, @canonical_policy, @isotope_stereo_policy
      rescue InvalidSmilesException => e
        flash[:error] = "Check your SMILES: #{e.message}".html_safe
      rescue Exception => e 
        flash[:error] = "unknown error occured: #{e.to_s}".html_safe
      end
    when :SMARTS
      begin
        @smiles_hash, @matched_atoms_lists = Seek::Search::Smiles.matchCompoundSmarts @visible_compound_id_smiles_hash, @structure_search_query
      rescue IllegalArgumentException => e
        flash[:error] = "Check your SMARTS: #{e.message}".html_safe
      rescue Exception => e 
        flash[:error] = "unknown error occured: #{e.to_s}".html_safe
      end
    when :SIMILARITY
      begin
        @smiles_hash, @coefficients = Seek::Search::Smiles.matchCompoundSimilarity @visible_compound_id_smiles_hash, @structure_search_query, @fingerprint_size, @fingerprint_search_depth, @tanimoto_coefficient_cutoff
      rescue InvalidSmilesException => e
        flash[:error] = "Check your SMILES: #{e.message}".html_safe
      rescue CDKException => e
        flash[:error] = "#{e.message}".html_safe
      rescue Exception => e 
        flash[:error] = "unknown error occured: #{e.to_s}".html_safe
      end
    else
      @smiles_hash = {}
    end
    
  end

  def molfile
    smiles = params[:SMILES]

    # smiles parser to generate atom container from smiles string
    smiles_parser = Cdk::Smiles::SmilesParser.new(Cdk::DefaultChemObjectBuilder.getInstance())

    molecule = nil
    begin
      molecule = smiles_parser.parseSmiles(smiles)
    rescue InvalidSmilesException
    end
    #we get molecule=Nil if a bot crawls here and it blows things up
    writer = Java::Io::StringWriter.new()
    if molecule
      # add coordinates
      sdg = Cdk::Layout::StructureDiagramGenerator.new()
      sdg.setMolecule(molecule,false)
      sdg.generateCoordinates()
      layed_out_mol = sdg.getMolecule();


      molwriter = Cdk::Io::MDLV2000Writer.new(writer)
      molwriter.writeMolecule(layed_out_mol)
    end
      render :partial => 'molfile',
             :content_type => "text/plain",
             :locals => { frame: writer.toString().to_s}

  end

  private

  # set class varibales that are used for search from the params
  def parse_params params
    @structure_search_query      = (params[:structure_search_query]                                         || DEFAULT_PARAMS[:structure_search_query]     )
    @search_type                 = (params.keys.find{|key| Seek::Search::Smiles::TYPES.has_key? key.to_sym} || DEFAULT_PARAMS[:search_type]                ).to_sym
    @canonical_policy            = (params[:canonical_policy]                                               || DEFAULT_PARAMS[:canonical_policy]           ).to_sym
    @isotope_stereo_policy       = (params[:isotope_stereo_policy]                                          || DEFAULT_PARAMS[:isotope_stereo_policy]      ).to_sym
    @fingerprint_size            = (params[:fingerprint_size]                                               || DEFAULT_PARAMS[:fingerprint_size]           ).to_i
    @fingerprint_search_depth    = (params[:fingerprint_search_depth]                                       || DEFAULT_PARAMS[:fingerprint_search_depth]   ).to_i
    @tanimoto_coefficient_cutoff = (params[:tanimoto_coefficient_cutoff]                                    || DEFAULT_PARAMS[:tanimoto_coefficient_cutoff]).to_f
  end

end