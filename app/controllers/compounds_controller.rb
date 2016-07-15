class CompoundsController < ApplicationController

  before_filter :find_requested_item, :only=>[:show,:edit,:update,:destroy]
  before_filter :login_required
  before_filter :is_user_admin_auth
  before_filter :find_all_compounds

  include Seek::FactorStudied

  def index
    respond_to do |format|
      format.html
      format.xml
    end
  end

   def create
      compound = params[:compound]
      compound_name =  compound[:title]

        unless compound_name.blank?
           unless Compound.find_by_name(compound_name)
             @compound = Compound.new(:name => compound_name)

             compound_annotation = {}
             compound_annotation['recommended_name'] = compound_name
             compound_annotation['synonyms'] = compound[:synonyms].split(';').collect{|s| s.strip}
             compound_annotation['sabiork_id'] = compound[:sabiork_id].strip.to_i unless compound[:sabiork_id].blank?
             compound_annotation['chebi_ids'] = compound[:chebi_ids].split(';').collect{|s| s.strip}
             compound_annotation['kegg_ids'] = compound[:kegg_ids].split(';').collect{|s| s.strip}

             #create new or update mappings and mapping_links
             @compound = new_or_update_mapping_links @compound, compound_annotation

             #create new or update synonyms
             @compound = new_or_update_synonyms @compound, compound_annotation
             render :update do |page|
               if @compound.save
                  page.insert_html :before, "compound_rows",:partial=>"compound_row",:object=> @compound
                  page.visual_effect :highlight,"compound_row_#{@compound.id}"
                  # clear the _add_compound form
                  page[:add_compound_form].reset
               else
                  page.alert(@compound.errors.full_messages)
               end
             end
           else
             render :update do |page|
              page.alert("The compound #{compound_name} already exist in SEEK. You can update it from the list of compounds below")
             end
           end
        else
           render :update do |page|
            page.alert('Please input the compound name')
           end
        end
   end

   def show
     respond_to do |format|
       format.rdf { render :template=>'rdf/show'}
     end
   end

   def update
      compound_name =  params["#{@compound.id}_title"]

      unless compound_name.blank?
         compound_annotation = {}
         compound_annotation['recommended_name'] = compound_name
         compound_annotation['synonyms'] = params["#{@compound.id}_synonyms"].split(';').collect{|s| s.strip}
         compound_annotation['sabiork_id'] = params["#{@compound.id}_sabiork_id"].strip.to_i unless params["#{@compound.id}_sabiork_id"].blank?
         compound_annotation['chebi_ids'] = params["#{@compound.id}_chebi_ids"].split(';').collect{|s| s.strip}
         compound_annotation['kegg_ids'] = params["#{@compound.id}_kegg_ids"].split(';').collect{|s| s.strip}

         @compound.title = compound_name
         #create new or update mappings and mapping_links
         @compound = new_or_update_mapping_links @compound, compound_annotation

         #create new or update synonyms
         @compound = new_or_update_synonyms @compound, compound_annotation
         render :update do |page|
           if @compound.save
              page.visual_effect :fade,"edit_compound_#{@compound.id}"
              page.replace "compound_row_#{@compound.id}", :partial => 'compound_row', :object => @compound
           else
              page.alert(@compound.errors.full_messages)
           end
         end
      else
         render :update do |page|
          page.alert('Please input the compound name')
         end
      end
   end

  def destroy
    #destroy the factor_studied, experimental_condition and their links
    @compound.studied_factors.each{|sf| sf.destroy}
    @compound.experimental_conditions.each{|ec| ec.destroy}
    #destroy the mapping_links
    @compound.mapping_links.each{|ml| ml.destroy}
    #destroy the synonyms and their links
    @compound.synonyms.each do |s|
      s.studied_factors.each{|sf| sf.destroy}
      s.experimental_conditions.each{|ec| ec.destroy}
      s.destroy
    end
    render :update do |page|
      if @compound.destroy
         page.visual_effect :fade, "compound_row_#{@compound.id}"
         page.visual_effect :fade, "edit_compound_#{@compound.id}"
      else
         page.alert(@compound.errors.full_messages)
      end
    end
  end

  def search_in_sabiork
     unless params[:compound_name].blank?
       compound_annotation = Seek::SabiorkWebservices.new().get_compound_annotation(params[:compound_name])
       unless compound_annotation.blank?
           synonyms = compound_annotation['synonyms'].inject{|result, s| result.concat("; #{s}")}
           synonyms.chomp!('; ') unless synonyms.blank?
           chebi_ids = compound_annotation['chebi_ids'].inject{|result, id| result.concat("; #{id}")}
           chebi_ids.chomp!('; ') unless synonyms.blank?
           kegg_ids = compound_annotation['kegg_ids'].inject{|result, id| result.concat("; #{id}")}
           kegg_ids.chomp!('; ') unless synonyms.blank?
           unless params[:id].blank?
             render :update do |page|
               page["#{params[:id]}_title"].value = compound_annotation["recommended_name"]
               page["#{params[:id]}_sabiork_id"].value = compound_annotation["sabiork_id"]
               page["#{params[:id]}_synonyms"].value = synonyms
               page["#{params[:id]}_chebi_ids"].value = chebi_ids
               page["#{params[:id]}_kegg_ids"].value = kegg_ids
               page.visual_effect :highlight, "edit_compound_#{params[:id]}"
             end
           else
             render :update do |page|
               page[:compound_title].value = compound_annotation["recommended_name"]
               page[:compound_sabiork_id].value = compound_annotation["sabiork_id"]
               page[:compound_synonyms].value = synonyms
               page[:compound_chebi_ids].value = chebi_ids
               page[:compound_kegg_ids].value = kegg_ids
               page.visual_effect :highlight, "add_compound_form"
             end
           end
       else
         render :update do |page|
           page.alert('No result found')
         end
       end
     else
        render :update do |page|
           page.alert('Please input the compound name')
         end
     end
  end

  # post function to search for compounds based on SMARTS/SMILES
  # @author woetzens
  def search
    @search_query = params[:structure_search_query]
    @search=@search_query # used for logging, and logs the origin search query - see ApplicationController#log_event
    @search_query||=""
    @search_type = params[:search_type].to_sym
    
    canonical_policy = params[:canonical_policy].to_sym
    isotope_stereo_policy = params[:isotope_stereo_policy].to_sym
    
    @compounds_hash = []
    
    case @search_type
    when :SMILES
      smiles = Seek::Search::Smiles.matchCompoundSmiles( Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash, @search_query, canonical_policy, isotope_stereo_policy)
      @compounds_hash = Seek::Data::CompoundsExtraction.get_compounds_hash.keep_if { |key,value| smiles.has_key? key}
    when :SMARTS
      smiles = Seek::Search::Smiles.matchCompoundSmarts Seek::Data::CompoundsExtraction.get_compound_id_smiles_hash, @search_query
      @compounds_hash = Seek::Data::CompoundsExtraction.get_compounds_hash.keep_if { |key,value| smiles.has_key? key}
    else
      @compounds_hash = []
    end
    
    respond_to do |format|
      format.html { render template: 'data_files/compounds_view' }
      # format.xml { render template: 'data_files/compounds_view' }
    end
  end

  # used as ajax action for creating a redbox containing a JSME molecular editor
  # @author woetzens
  def jsme_box
    respond_to do |format|
      format.html { render :partial => "compounds/jsme_box",
                           :locals => {}
                  }
    end
  end

  private  

  def find_all_compounds
     @compounds=Compound.order(:name)
  end

end