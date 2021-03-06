require "./spec_helper"

class TestResource < JSONApi::Resource
  def initialize(@id)
  end
end

class AttributesTestResource < JSONApi::Resource
  def initialize(@id, @attr_one, @attr_two)
  end

  attributes({
    attr_one: String,
    attr_two: Int32
  })
end

record RelationshipMock, foo do
  def to_json(io)
    io.json_object do |object|
      object.field(:foo, @foo)
    end
  end
end

class RelationshipsTestResource < JSONApi::Resource
  def initialize(@id, @related_test_id)
  end

  relationships({
    related_test: { to: :one, key: @related_test_id },
    other_tests: { to: :many }
  })
end

class MixedTestResource < JSONApi::Resource
  def initialize(@id, @attr_one, @attr_two, @related_test_id)
  end

  attributes({
    attr_one: String,
    attr_two: Int32
  })

  relationships({
    related_test: { to: :one, key: @related_test_id },
    other_tests: { to: :many }
  })
end

describe JSONApi::Resource do
  context ".to_json" do
    it "returns a json object" do
      resource = TestResource.new(1)
      json_object(resource)
    end

    it "adds a correct type field" do
      resource = TestResource.new(1)
      type = nil
      json_object(resource) do |key, pull|
        case(key)
        when "type" then type = pull.read_string
        else pull.skip
        end
      end

      type.should eq("test_resources")
    end

    it "adds a stringified id field" do
      resource = TestResource.new(1)
      id = nil
      json_object(resource) do |key, pull|
        case(key)
        when "id" then id = pull.read_string
        else pull.skip
        end
      end

      id.should eq("1")
    end

    it "doesn't add unsupported fields" do
      resource = TestResource.new(1)
      expected_fields = ["type", "id", "attributes", "relationships", "links", "meta"]
      json_object(resource) do |key, pull|
        (expected_fields.includes?(key)).should be_true
        pull.skip
      end
    end

    it "adds an attributes object if attributes is implemented" do
      resource = AttributesTestResource.new(1, "foo", 2)
      attr_one, attr_two = { nil, nil }
      json_object(resource) do |key, pull|
        case(key)
        when "attributes"
          pull.read_object do |attribute|
            attr_one = pull.read_string if attribute == "attr_one"
            attr_two = pull.read_int if attribute == "attr_two"
          end
        else pull.skip
        end
      end

      attr_one.should eq("foo")
      attr_two.should eq(2)
    end

    it "adds a correct links object" do
      resource = TestResource.new(1)
      self_link = nil

      json_object(resource) do |key, pull|
        case(key)
        when "links"
          pull.read_object do |key|
            case(key)
            when "self" then self_link = pull.read_string
            else pull.skip
            end
          end
        else pull.skip
        end
      end

      self_link.should eq("/api_test/v1/test_resources/1")
    end

    it "adds an relationships object if relationships is implemented" do
      expected_id = 2
      id = nil
      resource = RelationshipsTestResource.new(1, expected_id)
      json_object(resource) do |key, pull|
        case(key)
        when "relationships"
          pull.read_object do |key|
            case(key)
            when "related_test"
              pull.read_object do |key|
                case(key)
                when "data"
                  pull.read_object do |key|
                    case(key)
                    when "id" then id = pull.read_string
                    else pull.skip
                    end
                  end
                else pull.skip
                end
              end
            else pull.skip
            end
          end
        else pull.skip
        end
      end
      id.should eq(expected_id.to_s)
    end
  end

  context "get_attributes" do
    it "returns a hash of its attributes" do
      resource = AttributesTestResource.new(1, "foo", 2)
      resource.get_attributes.should eq({
        attr_one: "foo",
        attr_two: 2
      })
    end
  end

  context "get_relationships" do
    it "returns a hash of its relationships types and foreign keys (if any)" do
      resource = RelationshipsTestResource.new(1, 2)
      resource.get_relationships.should eq({
        related_test: { type: "related_tests", key: 2 }
      })
    end
  end

  context "update_attributes" do
    it "updates the attributes from a json" do
      resource = AttributesTestResource.new("1", "foo", 2)
      json = %<{"attr_one":"bar","attr_two":4}>
      resource.update_attributes(JSON::PullParser.new(json))
      resource.attr_one.should eq("bar")
      resource.attr_two.should eq(4)
    end
  end

  context "update_relationships" do
    it "updates relationships from a json" do
      resource = RelationshipsTestResource.new(1, "2")
      json = %<{"related_test":{"data":{"type":"related_tests","id":"3"}}}>
      resource.update_relationships(JSON::PullParser.new(json))
      resource.get_relationships.should eq({
        related_test: { type: "related_tests", key: "3" }
      })
    end
  end

  context "update" do
    it "updates attributes and relationships from a json" do
      resource = MixedTestResource.new(1, "foo", 2, "2")
      json = %<{"data":{"relationships":{"related_test":{"data":{"type":"related_tests","id":"3"}}},"attributes":{"attr_one":"bar","attr_two":4}}}>
      resource.update(JSON::PullParser.new(json))
      resource.attr_one.should eq("bar")
      resource.attr_two.should eq(4)
      resource.get_relationships.should eq({
        related_test: { type: "related_tests", key: "3" }
      })
    end
  end
end
