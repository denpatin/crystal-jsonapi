require "./success_response"

module JSONApi
  class ResourceResponse(T) < SuccessResponse
    def initialize(
      @resource : T?,
      self_link = nil : String?,
      @included = nil : (Enumerable(Resource) | Iterator(Resource))?
    )
      super(200)
      @self_link = self_link || @resource.try {
        "#{API_ROOT}/#{resource.type}/#{resource.id}"
      }
    end

    protected def serialize_data(object, io)
      object.field(:data, @resource)
    end

    protected def serialize_links(object, io)
      return unless self_link = @self_link
      object.field(:links) do
        io.json_object do |object|
          object.field(:self, self_link)
        end
      end
    end
  end
end
