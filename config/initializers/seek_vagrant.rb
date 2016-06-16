#Default values required for the automated unit, functional and integration testing to behave as expected.
SEEK::Application.configure do
  if Rails.env.vagrant?
    silence_warnings do
      Settings.defaults[:solr_enabled] = true
    end
  end
end

