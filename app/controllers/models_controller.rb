require 'libxml'
require 'bives'

class ModelsController < ApplicationController

  include WhiteListHelper
  include IndexPager
  include DotGenerator
  include Seek::AssetsCommon

  before_filter :models_enabled?
  before_filter :find_assets, :only => [:index]
  before_filter :find_and_authorize_requested_item, :except => [:build, :index, :new, :create, :request_resource, :preview, :test_asset_url, :update_annotations_ajax]
  before_filter :find_display_asset, :only => [:show, :download, :execute, :matching_data, :visualise, :export_as_xgmml, :compare_versions]
  before_filter :find_other_version, :only => [:compare_versions]

  include Seek::Jws::Simulator
  include Seek::Publishing::PublishingCommon
  include Seek::BreadCrumbs
  include Bives
  include Seek::DataciteDoi

  def find_other_version
    version = params[:other_version]
    @other_version = @model.find_version(version)
    if version.nil? || @other_version.nil?
      flash[:error] = "The other version to compare with was not specified, or it does not exist"
      redirect_to model_path(@model, :version => @display_model.version)
    end
  end

  def compare_versions
    select_blobs_for_comparison
    if @blob1 && @blob2
      begin
        json = compare @blob1.filepath, @blob2.filepath, ["reportHtml", "crnJson", "json", "SBML"]
        @crn = JSON.parse(json)["crnJson"]
        @comparison_html = JSON.parse(json)["reportHtml"]
      rescue Exception => e
        flash.now[:error]="there was an error trying to compare the two versions - #{e.message}"
      end
    else
      flash.now[:error]="One of the version files could not be found, or you are not authorized to examine it"
    end
  end

  def select_blobs_for_comparison
    blobs = @display_model.sbml_content_blobs
    blobs = [:file_id, :other_file_id].collect do |param_key|
      params[param_key] ? blobs.find { |blob| blob.id.to_s == params[param_key] } : blobs.first
    end
    @blob1=blobs[0]
    @blob2=blobs[1]
  end


  def visualise
    raise Exception.new("This #{t('model')} does not support Cytoscape") unless @display_model.contains_xgmml?
    @doc = find_xgmml_doc @display_model
    @cytoscape_elements, @layout = generate_cytoscape_json(@doc)
    render :cytoscape_js, :layout => false
  end

  # GET /models
  # GET /models.xml

  def new_version
    if handle_upload_data
      comments = params[:revision_comment]

      respond_to do |format|
        create_new_version comments
        create_content_blobs
        create_model_image @model, params[:model_image]
        format.html { redirect_to @model }
      end
    else
      flash[:error]=flash.now[:error]
      redirect_to @model
    end
  end

  def delete_model_metadata
    attribute=params[:attribute]
    if attribute=="model_type"
      delete_model_type params
    elsif attribute=="model_format"
      delete_model_format params
    end
  end

  def submit_to_sycamore
    @model = Model.find_by_id(params[:id])
    @display_model = @model.find_version(params[:version])
    error_message = nil
    if !Seek::Config.sycamore_enabled
      error_message = "Interaction with Sycamore is currently disabled"
    elsif !@model.can_download? && (params[:code].nil? || (params[:code] && !@model.auth_by_code?(params[:code])))
      error_message = "You are not allowed to simulate this #{t('model')} with Sycamore"
    end

    render :update do |page|
      if error_message.blank?
        page['sbml_model'].value = IO.read(@display_model.sbml_content_blobs.first.filepath).gsub(/\n/, '')
        page['sycamore-form'].submit()
      else
        page.alert(error_message)
      end
    end
  end

  def update_model_metadata
    attribute=params[:attribute]
    if attribute=="model_type"
      update_model_type params
    elsif attribute=="model_format"
      update_model_format params
    end
  end

  def delete_model_type params
    id=params[:selected_model_type_id]
    model_type=ModelType.find(id)
    success=false
    if (model_type.models.empty?)
      if model_type.delete
        msg="OK. #{model_type.title} was successfully removed."
        success=true
      else
        msg="ERROR. There was a problem removing #{model_type.title}"
      end
    else
      msg="ERROR - Cannot delete #{model_type.title} because it is in use."
    end

    render :update do |page|
      page.replace_html "model_type_selection", collection_select(:model, :model_type_id, ModelType.all, :id, :title, {:include_blank => "Not specified"}, {:onchange => "model_type_selection_changed();"})
      page.replace_html "model_type_info", "#{msg}<br/>"
      info_colour= success ? "green" : "red"
      page << "$('model_type_info').style.color='#{info_colour}';"
      page.visual_effect :appear, "model_type_info"
    end

  end

  def delete_model_format params
    id=params[:selected_model_format_id]
    model_format=ModelFormat.find(id)
    success=false
    if (model_format.models.empty?)
      if model_format.delete
        msg="OK. #{model_format.title} was successfully removed."
        success=true
      else
        msg="ERROR. There was a problem removing #{model_format.title}"
      end
    else
      msg="ERROR - Cannot delete #{model_format.title} because it is in use."
    end

    render :update do |page|
      page.replace_html "model_format_selection", collection_select(:model, :model_format_id, ModelFormat.all, :id, :title, {:include_blank => "Not specified"}, {:onchange => "model_format_selection_changed();"})
      page.replace_html "model_format_info", "#{msg}<br/>"
      info_colour= success ? "green" : "red"
      page << "$('model_format_info').style.color='#{info_colour}';"
      page.visual_effect :appear, "model_format_info"
    end
  end


  # GET /models/1
  # GET /models/1.xml
  def show
    # store timestamp of the previous last usage
    @last_used_before_now = @model.last_used_at


    @model.just_used

    respond_to do |format|
      format.html # show.html.erb
      format.xml
      format.rdf { render :template => 'rdf/show' }
    end
  end

  # GET /models/new
  # GET /models/new.xml
  def new
    @model=Model.new
    @content_blob= ContentBlob.new
    respond_to do |format|
      if User.logged_in_and_member?
        format.html # new.html.erb
      else
        flash[:error] = "You are not authorized to upload new Models. Only members of known projects, institutions or work groups are allowed to create new content."
        format.html { redirect_to models_path }
      end
    end
  end

  # GET /models/1/edit
  def edit

  end

  # POST /models
  # POST /models.xml
  def create
    if handle_upload_data
      @model = Model.new(params[:model])

      @model.policy.set_attributes_with_sharing params[:sharing], @model.projects

      update_annotations @model
      update_scales @model
      build_model_image @model, params[:model_image]

      respond_to do |format|
        if @model.save
          create_content_blobs
          update_relationships(@model, params)
          update_assay_assets(@model, params[:assay_ids])
          flash[:notice] = "#{t('model')} was successfully uploaded and saved."
          format.html { redirect_to model_path(@model) }
        else
          format.html {
            render :action => "new"
          }
        end
      end
    else
      handle_upload_data_failure
    end

  end


  # PUT /models/1
  # PUT /models/1.xml
  def update
    # remove protected columns (including a "link" to content blob - actual data cannot be updated!)
    model_params=filter_protected_update_params(params[:model])

    update_annotations @model
    update_scales @model

    @model.attributes = model_params

    if params[:sharing]
      @model.policy_or_default
      @model.policy.set_attributes_with_sharing params[:sharing], @model.projects
    end

    respond_to do |format|
      if @model.save

        update_relationships(@model, params)
        update_assay_assets(@model, params[:assay_ids])

        flash[:notice] = "#{t('model')} metadata was successfully updated."
        format.html { redirect_to model_path(@model) }
      else
        format.html {
          render :action => "edit"
        }
      end
    end
  end

  def matching_data
    #FIXME: should use the correct version
    @matching_data_items = @model.matching_data_files

    #filter authorization
    ids = @matching_data_items.collect &:primary_key
    data_files = DataFile.find_all_by_id(ids)
    authorised_ids = DataFile.authorize_asset_collection(data_files, "view").collect &:id
    @matching_data_items = @matching_data_items.select { |mdf| authorised_ids.include?(mdf.primary_key.to_i) }

    flash.now[:notice]="#{@matching_data_items.count} #{t('data_file').pluralize} found that may be relevant to this #{t('model')}"
    respond_to do |format|
      format.html
    end
  end

  protected

  def create_new_version comments
    if @model.save_as_new_version(comments)
      flash[:notice]="New version uploaded - now on version #{@model.version}"
    else
      flash[:error]="Unable to save new version"
    end
  end

  def translate_action action
    action="view" if ["matching_data"].include?(action)
    super action
  end

  def jws_enabled
    unless Seek::Config.jws_enabled
      respond_to do |format|
        flash[:error] = "Interaction with JWS Online is currently disabled"
        format.html { redirect_to model_path(@model, :version => @display_model.version) }
      end
      return false
    end
  end

  def build_model_image model_object, params_model_image
    unless params_model_image.blank? || params_model_image[:image_file].blank?

      # the creation of the new Avatar instance needs to have only one parameter - therefore, the rest should be set separately
      @model_image = ModelImage.new(params_model_image)
      @model_image.model_id = model_object.id
      @model_image.content_type = params_model_image[:image_file].content_type
      @model_image.original_filename = params_model_image[:image_file].original_filename
      model_object.model_image = @model_image
    end

  end

  def find_xgmml_doc model
    xgmml_content_blob = model.xgmml_content_blobs.first
    doc = File.read(xgmml_content_blob.filepath)
  end

  def create_model_image model_object, params_model_image
    build_model_image model_object, params_model_image
    model_object.save(:validate => false)
    latest_version = model_object.latest_version
    latest_version.model_image_id = model_object.model_image_id
    latest_version.save
  end

  def generate_cytoscape_json xml_doc_string
    hash_string = Hash.from_xml(xml_doc_string.gsub(/type="string"/, 'type="text"'))
    cytoscape_elements_hash = {"nodes" => hash_string["graph"]["node"].map { |n| {"data" => flatten_hash(n)} },
                               "edges" => hash_string["graph"]["edge"].map { |n| {"data" => flatten_hash(n)} }}
    cytoscape_elements_hash = {"nodes" => cytoscape_elements_hash["nodes"].map { |n| {"data" => rebuild_cytoscape_hash(n["data"]).reject { |k, v| k.include? "edge_" }, "position" => {"x" => n["data"]["graphics<<x"].to_f, "y" => n["data"]["graphics<<y"].to_f}} },
                               "edges" => cytoscape_elements_hash["edges"].map { |n| {"data" => rebuild_cytoscape_hash(n["data"]).reject { |k, v| k.include? "node_" }} }}

    cytoscape_layout = "random"
    defined_layout = hash_string["graph"]["att"].detect { |a| a["name"].downcase.include? "layout" }
    cytoscape_layout = defined_layout["value"] if defined_layout
    position = cytoscape_elements_hash["nodes"].detect { |n| n["data"]["x"] && n["data"]["y"] }
    cytoscape_layout = "preset" if position
    layout_hash = {"name" => cytoscape_layout}

    [cytoscape_elements_hash.to_json, layout_hash.to_json]
  end

  def flatten_hash(hash)
    hash.each_with_object({}) do |(k, v), h|
      if v.is_a? Hash
        flatten_hash(v).map do |h_k, h_v|
          new_h_k = "#{k}<<#{h_k}"
          h[new_h_k] = h_v
        end
      else
        h[k] = v
      end
    end
  end


  def rebuild_cytoscape_hash hash
    new_hash = hash.each_with_object({}) do |(k, v), h|
      #change ":" to "_" in the key
      if k.include?(":")
        h[k.gsub(/:/, "##")] = v
        #mapping postion keys to cytoscape styles
      elsif k == "graphics<<x" || k == "graphics<<y"
        h[k.split("<<").last] = v.to_f
      else
        h[k] = v
      end
    end

    add_default_cytoscape_values(new_hash)
  end

  def add_default_cytoscape_values(hash)
    style_mapping = YAML.load(File.read("#{Rails.root}/config/cytoscapejs/attributes_mapping.yml"))
    default_styles_hash = style_mapping.each_with_object({}) do |(key, value), new_h|
      new_value = find_or_set_default_hash(hash, value["attribute_name"], value["default_value"])
      new_value = rgb2hex(new_value) if key.downcase.include?("color") && new_value && !new_value.include?("#")
      new_h[key] = new_value
    end

    hash.reverse_merge default_styles_hash
  end

  def find_or_set_default_hash hash, keywords, default_value
    att_names = hash["att"].map { |a| a["name"] }
    key = (hash.keys + att_names).detect { |k| Array(keywords).detect { |kw| k.downcase.include?(kw.downcase) } }
    att_value = hash["att"].detect { |a| a["name"]==key }.try { |h| h["value"] }
    hash[key].blank? && att_value.blank? ? default_value : hash[key] || att_value
  end

  def rgb2hex rgb_string
    color_hex = rgb_string.split(",").map do |c|
      hex = c.to_i.to_s(16)
      c.to_i > 16 ? hex : "0#{hex}"
    end.join("")

    "##{color_hex}"
  end
end
