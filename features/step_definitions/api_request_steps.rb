require 'source_helper'

### GIVEN ###
Given /^we have (\d+) API requests$/ do |number|
  FactoryGirl.create_list(:api_request, number.to_i)
end

### WHEN ###
When /^I make (\d+) API requests$/ do |number|
  article = FactoryGirl.create(:article)
  (number.to_i).times do
    visit api_v3_article_path(article)
  end
end

### THEN ###
Then(/^I should see (\d+) API requests were made$/) do |number|
  page.has_css?('span#total', :text => number).should be_true
end