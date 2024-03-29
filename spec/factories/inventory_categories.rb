# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :inventory_category, :class => 'Inventory::Category' do
    title { generate(:name) }
    description "A cool category"
    plot_format "pin"
    color '#f2f2f2'
    require_item_status false

    icon { fixture_file_upload(Rails.root.join('spec/fixtures/images/valid_report_category_icon.png')) }
    marker { fixture_file_upload(Rails.root.join('spec/fixtures/images/valid_report_category_marker.png')) }
    pin { fixture_file_upload(Rails.root.join('spec/fixtures/images/valid_report_category_marker.png')) }

    factory :inventory_category_with_sections do
      after(:create) do |category, evaluator|
        create_list(:inventory_section_with_fields, 3, category: category)
      end
    end
  end
end
