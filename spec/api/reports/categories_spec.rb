require 'spec_helper'

describe Reports::Categories::API do
  let(:user) { create(:user) }
  let!(:inventory_categories) { create_list(:inventory_category, 3) }
  let(:valid_params) do
    {
        title: 'A very cool report category',
        icon: Base64.encode64(fixture_file_upload('images/valid_report_category_icon.png').read),
        marker: Base64.encode64(fixture_file_upload('images/valid_report_category_marker.png').read),
        resolution_time: 2 * 60 * 60 * 24,
        user_response_time: 1 * 60 * 60 * 24,
        color: '#f3f3f3',
        inventory_categories: inventory_categories.map(&:id),
        statuses: {
          0 =>  { title: 'Open', color: '#ff0000', initial: true, final: false, active: true },
          1 =>  { title: 'Closed', color: '#f4f4f4', final: true, initial: false, active: false }
        }
    }
  end

  context 'POST /reports/categories' do
    it 'creates the report category provided valid params are given' do
      post '/reports/categories', valid_params, auth(user)
      expect(response.status).to eq(201)
      body = parsed_body

      statuses = body['category']['statuses'].map { |st| st['title'] }
      expect(statuses).to match_array(['Open', 'Closed'])

      valid_params.except(:inventory_categories, :token, :statuses, :marker, :icon).each do |param_key, param_value|
        expect(body['category'][param_key.to_s]).to eq(param_value)
      end

      expect(body['category']['inventory_categories']).to_not be_empty
      expect(body['category']['marker']).to_not be_empty
      expect(body['category']['icon']).to_not be_empty
    end

    it 'validates the format of the status' do
      valid_params[:statuses] = {
        0 => { test: '11' },
        1 => { test: '11' }
      }

      post '/reports/categories', valid_params, auth(user)
      expect(response.status).to eq(400)
      body = parsed_body

      expect(body['error'].keys).to match_array(['title', 'color', 'initial', 'final', 'active'])
    end
  end

  context 'GET /reports/categories/:id' do
    it 'should display an category' do
      category = fg.create(:reports_category_with_statuses)
      get '/reports/categories/' + category.id.to_s
      expect(response.status).to eq(200)
      body = JSON.parse(response.body)['category']
      expect(body['id']).to eq(category.id)
    end
  end

  context 'GET /reports/categories' do
    let!(:categories) { create_list(:reports_category_with_statuses, 3) }

    it 'displays a list of categories including control properties' do
      get '/reports/categories?display_type=full', nil, auth(user)
      body = parsed_body["categories"]

      expect(body.count).to eq(3)

      body.each do |category|
        expect(category).to include('id')
        expect(category).to include('icon')
        expect(category['icon']).to_not be_empty
        expect(category).to include('marker')
        expect(category['marker']).to_not be_empty
        expect(category).to include('resolution_time')
        expect(category).to include('user_response_time')
        expect(category).to include('statuses')
        expect(category['statuses'].count).to eq(4)
        expect(category).to include('allows_arbitrary_position')
        expect(category).to include('created_at')
        expect(category).to include('updated_at')
        expect(category).to include('active')
      end
    end

    it 'displays a lit of categories, excluding control properties' do
      get '/reports/categories', nil, auth(user)
      body = parsed_body["categories"]

      expect(body.count).to eq(3)

      body.each do |category|
        expect(category).to include('id')
        expect(category).to include('icon')
        expect(category['icon']).to_not be_empty
        expect(category).to include('marker')
        expect(category['marker']).to_not be_empty
        expect(category).to include('resolution_time')
        expect(category).to include('user_response_time')
        expect(category).to include('statuses')
        expect(category['statuses'].count).to eq(4)
        expect(category).to include('allows_arbitrary_position')
        expect(category).to_not include('created_at')
        expect(category).to_not include('updated_at')
        expect(category).to_not include('active')
      end
    end
  end

  context 'PUT /reports/categories/:id' do
    it 'should update a category' do
      category = create(:reports_category_with_statuses)

      put '/reports/categories/' + category.id.to_s, valid_params, auth(user)
      expect(response.status).to eq(204)

      category.reload

      expect(category.statuses.map { |s| s.title }).to match_array(['Open', 'Closed'])

      expect(category.inventory_categories.pluck(:id)).to \
        eq(valid_params[:inventory_categories])

      valid_params.except(:inventory_categories, :token, :statuses, :marker, :icon).each do |param_key, param_value|
        expect(category[param_key.to_s]).to eq(param_value)
      end

      expect(category[:icon]).to_not be_empty
      expect(category[:marker]).to_not be_empty
    end
  end

  context 'DELETE /reports/categories/:id' do
    let(:category) { create(:inventory_category) }

    it 'destroys a reports category' do
      category = create(:reports_category_with_statuses)
      delete "/reports/categories/#{category.id}", nil, auth(user)
      expect(response.status).to eq(204)
      expect(Reports::Category.find_by(id: category.id)).to be_nil
    end
  end
end
