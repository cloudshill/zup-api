require "spec_helper"

describe Search::Inventory::Items::API do

  let(:user) { create(:user) }

  describe "GET /search/inventory/items" do

    let(:category) { create(:inventory_category_with_sections) }

    context "by address" do
      let(:items) do
        create_list(:inventory_item, 10, category: category)
      end
      let(:valid_params) do
        JSON.parse <<-JSON
          {
            "address": "abilio"
          }
        JSON
      end

      it "returns the correct items with the correct address" do
        correct_item = items.sample
        correct_item.update(address: 'Rua Abilio Soares, 140')

        get "/search/inventory/items", valid_params, auth(user)
        expect(parsed_body['items'].first['id']).to eq(correct_item.id)
      end
    end

    context "by query" do
      let!(:items) do
        create_list(:inventory_item, 5, category: category)
      end
      let!(:correct_items) do
        item = items.sample
        items.delete(item)
        item.update(title: "Tree 123456")

        item2 = items.sample
        items.delete(item2)
        item2.update(address: "123456 ol street")

        item3 = items.sample
        items.delete(item3)
        item3.update(id: 123456)

        [item, item2, item3]
      end
      let(:valid_params) do
        JSON.parse <<-JSON
          {
            "query": "123456"
          }
        JSON
      end

      it "returns the correct items" do
        get "/search/inventory/items", valid_params, auth(user)
        expect(parsed_body['items'].map do |r|
          r['id']
        end).to match_array(correct_items.map(&:id))
      end
    end


    context "by user ids" do
      let!(:user) { create(:user) }
      let!(:user2) { create(:user) }
      let!(:items) do
        create_list(:inventory_item, 3, category: category)
      end
      let!(:correct_items) do
        item = items.sample
        items.delete(item)
        item.update(user_id: user.id)

        item2 = items.sample
        items.delete(item2)
        item2.update(user_id: user2.id)

        [item, item2]
      end
      let(:valid_params) do
        JSON.parse <<-JSON
          {
            "users_ids": "#{user.id},#{user2.id}"
          }
        JSON
      end

      before do
        get "/search/inventory/items", valid_params, auth(user)
      end

      it "returns the correct items with the correct address" do
        expect(parsed_body['items'].map do |i|
          i['id']
        end).to match_array(correct_items.map(&:id))
      end
    end

    context "by title" do
      let(:items) do
        create_list(:inventory_item, 10, category: category)
      end
      let(:valid_params) do
        JSON.parse <<-JSON
          {
            "title": "torta"
          }
        JSON
      end

      it "returns the correct items with the correct address" do
        correct_item = items.sample
        correct_item.update(title: 'Árvore torta')

        get "/search/inventory/items", valid_params, auth(user)
        expect(parsed_body['items'].first['id']).to eq(correct_item.id)
      end
    end


    context "by multiple positions" do
      let(:items) do
        create_list(:inventory_item, 10, category: category)
      end
      let(:latitude) { -23.5505200 }
      let(:longitude) { -46.6333090 }
      let(:latitude2) { -20.5505200 }
      let(:longitude2) { -20.6333090 }

      let(:valid_params) do
        JSON.parse <<-JSON
          {
            "address": "abilio",
            "position": {
              "0": {
                "latitude": #{latitude},
                "longitude": #{longitude},
                "distance": 1000
              },
              "1": {
                "latitude": #{latitude2},
                "longitude": #{longitude2},
                "distance": 1000
              }
            }
          }
        JSON
      end

      it "returns the correct items with both positions args" do
        items.each do |item|
          item.update_attribute(
            :position, Reports::Item.rgeo_factory.point(-1, -1)
          )
        end

        correct_item_1 = items.first
        correct_item_1.update_attribute(
          :position, Reports::Item.rgeo_factory.point(longitude, latitude)
        )

        correct_item_2 = items.last
        correct_item_2.update_attribute(
          :position, Reports::Item.rgeo_factory.point(longitude2, latitude2)
        )

        get "/search/inventory/items", valid_params, auth(user)
        expect(parsed_body['items'].map do
          |r| r['id']
        end).to match_array([correct_item_1.id, correct_item_2.id])
      end

    end

    context "by address or position" do
      let(:items) do
        create_list(:inventory_item, 10, category: category)
      end
      let(:latitude) { -23.5505200 }
      let(:longitude) { -46.6333090 }
      let(:valid_params) do
        JSON.parse <<-JSON
          {
            "address": "abilio",
            "position": {
              "latitude": #{latitude},
              "longitude": #{longitude},
              "distance": 1000
            }
          }
        JSON
      end

      it "returns the correct items with address, position or both" do
        items.each do |item|
          item.update_attribute(
            :position, Reports::Item.rgeo_factory.point(-1, -1)
          )
        end

        correct_item_1 = items.first
        correct_item_1.update(address: 'Rua Abilio Soares, 140')

        correct_item_2 = items.last
        correct_item_2.update_attribute(
          :position, Reports::Item.rgeo_factory.point(longitude, latitude)
        )

        get "/search/inventory/items", valid_params, auth(user)
        expect(parsed_body['items'].map do
          |r| r['id']
        end).to match_array([correct_item_1.id, correct_item_2.id])
      end
    end

    context "by status" do
      let(:status) { create(:inventory_status, category: category) }
      let(:wrong_status) { create(:inventory_status, category: category) }
      let!(:items) do
        create_list(:inventory_item, 3, category: category, status: status)
      end
      let!(:wrong_items) do
        create_list(:inventory_item, 3, category: category, status: wrong_status)
      end
      let(:valid_params) do
        JSON.parse <<-JSON
          {
            "inventory_statuses_ids": "#{status.id}"
          }
        JSON
      end

      it "returns the correct items with the correct address" do
        get "/search/inventory/items", valid_params, auth(user)
        expect(parsed_body['items'].map do |i|
          i['id']
        end).to match_array(items.map(&:id))
      end
    end

    context "by created_at" do
      let!(:items) do
        create_list(:inventory_item, 3, category: category)
      end
      let!(:correct_item) do
        item = items.sample
        item.update(created_at: DateTime.new(2014, 1, 10))
        item
      end
      let!(:wrong_items) do
        items.delete(correct_item)
      end
      let(:valid_params) do
        JSON.parse <<-JSON
          {
            "created_at": {
              "begin": "#{Date.new(2014, 1, 9).iso8601}",
              "end": "#{Date.new(2014, 1, 13).iso8601}"
            }
          }
        JSON
      end

      before do
        get "/search/inventory/items", valid_params, auth(user)
      end

      it "returns the correct item" do
        expect(parsed_body['items'].map do |i|
          i['id']
        end).to eq([correct_item.id])
      end
    end

    context "by field content" do
      let!(:field) { create(:inventory_field, section: category.sections.sample) }

      context "using the lesser_than" do

        let!(:items) do
          create_list(:inventory_item, 3, category: category)
        end
        let!(:correct_item) do
          item = items.sample
          item.data.find_by(field: field).update!(content: 20)
          item
        end
        let!(:wrong_items) do
          items.delete(correct_item)
          items.each do |item|
            item.data.find_by(field: field).update!(content: 30)
          end
        end
        let(:valid_params) do
          JSON.parse <<-JSON
          {
            "fields": {
              "#{field.id}": {
                "lesser_than": 30
              }
            }
          }
          JSON
        end

        before do
          field.update(kind: "integer")
          get "/search/inventory/items", valid_params, auth(user)
        end

        it "returns the correct item" do
          expect(parsed_body['items'].map do |i|
            i['id']
          end).to eq([correct_item.id])
        end

      end

      context "using the greater_than" do

        let!(:items) do
          create_list(:inventory_item, 3, category: category)
        end
        let!(:correct_item) do
          item = items.sample
          item.data.find_by(field: field).update!(content: 30)
          item
        end
        let!(:wrong_items) do
          items.delete(correct_item)
          items.each do |item|
            item.data.find_by(field: field).update!(content: 20)
          end
        end
        let(:valid_params) do
          JSON.parse <<-JSON
          {
            "fields": {
              "#{field.id}": {
                "greater_than": 29
              }
            }
          }
          JSON
        end

        before do
          field.update(kind: "integer")
          get "/search/inventory/items", valid_params, auth(user)
        end

        it "returns the correct item" do
          expect(parsed_body['items'].map do |i|
            i['id']
          end).to eq([correct_item.id])
        end

      end

      context "using equal_to" do

        let!(:items) do
          create_list(:inventory_item, 3, category: category)
        end
        let!(:correct_item) do
          item = items.sample
          item.data.find_by(field: field).update!(content: 30)
          item
        end
        let!(:wrong_items) do
          items.delete(correct_item)
          items.each do |item|
            item.data.find_by(field: field).update!(content: 20)
          end
        end
        let(:valid_params) do
          JSON.parse <<-JSON
          {
            "fields": {
              "#{field.id}": {
                "equal_to": 30
              }
            }
          }
          JSON
        end

        before do
          field.update(kind: "integer")
          get "/search/inventory/items", valid_params, auth(user)
        end

        it "returns the correct item" do
          expect(parsed_body['items'].map do |i|
            i['id']
          end).to eq([correct_item.id])
        end

      end

      context "using different" do

        let!(:items) do
          create_list(:inventory_item, 3, category: category)
        end
        let!(:correct_item) do
          item = items.sample
          item.data.find_by(field: field).update!(content: 30)
          item
        end
        let!(:wrong_items) do
          items.delete(correct_item)
          items.each do |item|
            item.data.find_by(field: field).update!(content: 20)
          end
        end
        let(:valid_params) do
          JSON.parse <<-JSON
          {
            "fields": {
              "#{field.id}": {
                "different": 20
              }
            }
          }
          JSON
        end

        before do
          field.update(kind: "integer")
          get "/search/inventory/items", valid_params, auth(user)
        end

        it "returns the correct item" do
          expect(parsed_body['items'].map do |i|
            i['id']
          end).to eq([correct_item.id])
        end

      end

      context "using like" do

        let!(:items) do
          create_list(:inventory_item, 3, category: category)
        end
        let!(:correct_item) do
          item = items.sample
          item.data.find_by(field: field).update!(content: "correct_test")
          item
        end
        let!(:wrong_items) do
          items.delete(correct_item)
          items.each do |item|
            item.data.find_by(field: field).update!(content: "wrong_test")
          end
        end
        let(:valid_params) do
          JSON.parse <<-JSON
          {
            "fields": {
              "#{field.id}": {
                "like": "correct"
              }
            }
          }
          JSON
        end

        before do
          get "/search/inventory/items", valid_params, auth(user)
        end

        it "returns the correct item" do
          expect(parsed_body['items'].map do |i|
            i['id']
          end).to eq([correct_item.id])
        end

      end


      context "using includes" do
        let!(:field) { create(:inventory_field, section: category.sections.sample, kind: "checkbox") }
        let!(:items) do
          create_list(:inventory_item, 3, category: category)
        end
        let!(:correct_items) do
          item = items.sample
          items.delete(item)
          item.data.find_by(field: field).update!(content: ['this', 'is', 'a test'])

          item2 = items.sample
          items.delete(item2)
          item2.data.find_by(field: field).update!(content: ['is', 'a test'])

          [item, item2]
        end
        let!(:wrong_items) do
          items.each do |item|
            item.data.find_by(field: field).update!(content: ['crazy stuff'])
          end
        end
        let(:valid_params) do
          JSON.parse <<-JSON
          {
            "fields": {
              "#{field.id}": {
                "includes": ["is", "a test"]
              }
            }
          }
          JSON
        end

        before do
          get "/search/inventory/items", valid_params, auth(user)
        end

        it "returns the correct item" do
          expect(parsed_body['items'].map do |i|
            i['id']
          end).to match_array(correct_items.map(&:id))
        end

      end

      context "using excludes" do
        let!(:field) { create(:inventory_field, section: category.sections.sample, kind: "checkbox") }
        let!(:items) do
          create_list(:inventory_item, 3, category: category)
        end
        let!(:correct_items) do
          item = items.sample
          items.delete(item)
          item.data.find_by(field: field).update!(content: ['pretty', 'crazy', 'stuff'])

          item2 = items.sample
          items.delete(item2)
          item2.data.find_by(field: field).update!(content: ['another', 'pretty'])

          [item, item2]
        end
        let!(:wrong_items) do
          items.each do |item|
            item.data.find_by(field: field).update!(content: ['is', 'a test', 'crazy'])
          end
        end
        let(:valid_params) do
          JSON.parse <<-JSON
          {
            "fields": {
              "#{field.id}": {
                "excludes": ["is", "a test"]
              }
            }
          }
          JSON
        end

        before do
          get "/search/inventory/items", valid_params, auth(user)
        end

        it "returns the correct item" do
          expect(parsed_body['items'].map do |i|
            i['id']
          end).to match_array(correct_items.map(&:id))
        end

      end


    end

    context "sorting" do
      context "by title" do
        let!(:items) do
          items = create_list(:inventory_item, 3, category: category)
          items.sort_by { |item| item.title }
        end
        let(:valid_params) do
          JSON.parse <<-JSON
          {
            "sort": "title",
            "order": "asc"
          }
          JSON
        end

        before do
          get "/search/inventory/items", valid_params, auth(user)
        end

        it "returns the items on the correct order" do
          expect(parsed_body['items'].map do |i|
            i['id']
          end).to eq(items.map(&:id))
        end
      end
    end
  end

end
