#import "@preview/diatypst:0.8.0": *
#set outline(depth: 1)

#show: slides.with(
  title: "View Object Pattern", // Required
  subtitle: "View layer in Hikakaku-cms",
  date: datetime.today().display(),
  authors: "Tien Bui Gia",

  // Optional Styling (for more and explanation of options take a look at the typst universe)
  ratio: 16 / 9,
  layout: "medium",
  title-color: blue.darken(60%),
  toc: true,
)

#set grid(
  inset: 5pt,
  align: horizon,
)

== Note

#grid(
  columns: (auto, auto),
  text[
    - View Object $=$ Presenter

    - Decorator $!=$ Presenter

    - Decorator $=$ Wrapper
  ],
  image("assets/Watashi_Design_Patterns.jpg"),
)

= View layer

== MVC

#image("assets/mvc_architecture_light.jpg")

= Vấn đề

== ERB

```erb
<!-- app/views/user/_notifications.html.erb -->
<div id="notifications">
  <% unread_count = @current_user.notifications.unread.count %>
  <% if unread_count > 0 %>
    You have <%= unread_count %> unread
    <%= pluralize(unread_count, "notification") %>
  <% else %>
    You don't have unread notifications.
  <% end %>
</div>
```

- Business logic trong views.
- Biến đổi, truy cập database từ views.
- Khó test độc lập.

== Models

```ruby
# app/model/user.rb
include ActionView::Helpers::TextHelper
# ...

def unread_notifications_text
  unread_count = notifications.unread.count

  if unread_count == 0
    return "You don't have unread notifications."
  end

  "You have #{unread_count} unread #{pluralize(unread_count, 'notification')}".
end
```

- Presentation logic trong models.
- Models trở nên quá "béo".
- Khó maintain.

== Helpers thì sao?

Helpers OK nhưng cần hạn chế vì:

- Helpers thường dùng để truy vấn database.
  ```ruby
  visible_comments_for(article)
  ```
- Helpers tạo HTML tags => Khó sửa markup.
- Không rõ ràng giá trị truyền vào.
  ```ruby
  prepare_output(article.body)
  ```
- Khó theo dõi dependencies.
- Dễ test hơn logic trong views nhưng vẫn hạn chế.

= Decorator / Wrapper

== Decorator

/ Decorator Pattern: Thêm hành vi cho một object cụ thể.

```ruby
# app/models/concerns/decoratable.rb
module Decoratable
  def decorate
    "#{self.class}Decorator".constantize.new(self)
  end
end
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include Decoratable
# ...
```

```ruby
# app/decorators/user_decorater.rb
class UserDecorator < SimpleDelegator
  include ActionView::Helpers::TextHelper

  def unread_notifications_text
    # ...
  end
end
```

```ruby
class UsersController < ApplicationController
  # ...

  def index
    @users = User.recent.limit(50).map(&:decorate)
  end
end
```

== Decorator trong thực tế

```ruby
class ProductDecorator < Draper::Decorator
  delegate_all

  include ActionView::Helpers::NumberHelper

  # 文字情報でDBに保存されているテキストを表示、未記入の場合は「お問い合わせください」が表示される。
  def price
    return 'お問い合わせください' if self.object.price.blank?
    self.object.price
  end
# ...
```

```erb
              <% else %>
                <div class='info_value'><%= @product.decorate.price %></div>
                <span class='form_link'>詳細を見る</span>
              <% end %>

```

== Decorator là chưa đủ

- Decorator là giải pháp clean và hợp lý.
  - Đưa view logic vào 1 file riêng.
  - Tránh làm "béo" models.

- Nhưng gặp vấn đề khi view cần logic phức tạp từ *2 model* không liên quan.

- Hoặc khi logic không liên quan gì đến model.

= View Object / Presenter

== View Object

/ View Object Pattern: Đưa tất cả logic bạn cần trong views vào View Objects.

=== Mục tiêu logic trong views

1. Chỉ dùng 1 chấm (Law of Demeter).
  - #text(fill: red)[`@user.notifications.unread.count`]
  - #text(fill: green)[`user_vo.notification_count`]
2. Không truy vấn database.
3. Tránh tạo biến trong views.

#pagebreak()

```ruby
class IssuesPresenter
  attr_reader :issues, :filters

  def initialize(issues, filters)
    @issues, @filters = issues, filters
  end

  def has_selected_filters?
    filter.any?
  end

  def all_issues_are_resolved?
    issues.all?(:resolved?)
  end
end
```

```erb
<%= if @issues.all_issues_are_resolved? %>
  <%= if @issues.has_selected_filters? %>
    All selected issues are resolved.
  <% else %>
    All issues are resolved.
  <% end %>
<% end %>
```

== View Object: lợi thế

#grid(
  columns: (auto, auto),
  text[
    - _View Objects_ là PORO, nên có thể OOP.

    - _View Objects_ ko bị bó chặt với 1 model cụ thể.

    - _View Objects_ có thể test dễ dàng như ruby classes.
  ],
  image("assets/oh-yeah-simpson.jpg"),
)

= Hikakaku CMS

== Hikakaku CMS

Dự án đang có 2 phương pháp để quản lý View Object:

+ Sử dụng `view_object` gem.
  ```ruby
  # Gemfile
  gem 'view_object', '~> 0.2.0'
  ```
  ```ruby
  # app/controllers/estimate_forms_controller.rb
  class EstimateFormsController < EstimateFormsControllerBase
  include ViewObject
  ```
+ Tự quản lý bằng code `ViewObjectBridge`.
  ```ruby
  class ApplicationController < ActionController::Base
    # ...
    include ViewObjectBridge
  ```

== Gem thú vị

#grid(
  columns: (auto, auto),
  text[
    - Tác giả: kawaokas.

    - Commit cuối từ tháng 3/2019.

    - 1 star trên GitHub (của em).
    #image("assets/view_object_no_star.png")
    https://github.com/kawokas/view_object
  ],
  image("assets/kawakas_avatar.png"),
)

== Gem: Flow hoạt động

+ Controller include `ViewObject` module
+ Gem tự động thêm `before_action` callback
+ Callback gọi `dispatch_view_object`
+ Dispatcher tìm class theo naming convention
+ Khởi tạo view object và gán `@controller`
+ Gọi `after_initialize` nếu có
+ Gán vào `@view_object` instance variable

== Gem: Code chi tiết

```ruby
# Gem: lib/view_object.rb
module ViewObject
  extend ActiveSupport::Concern
  # ...

  included do
    define_callbacks :render
    before_render { view_object_before_render(self) }
    before_action { dispatch_view_object(self) }  # Tự động chạy
  end

  def dispatch_view_object(controller)
    return unless is_view_object_only_action(...)
    return if is_view_object_ignore_action(...)
    Dispatcher.dispatch_view_object(controller)  # Tìm và khởi tạo
  end
  # ...
```

```ruby
# Gem: lib/view_object/dispatcher.rb
module ViewObject
  class Dispatcher
    def self.dispatch_view_object(controller)
      vo = make_view_object(controller)
      controller.instance_variable_set(:@view_object, vo)
    end
```

== Gem: Hạn chế

+ Không hỗ trợ truyền tham số vào view object
+ View object phải truy cập controller qua `@controller`
+ Không có parameter validation
+ Không hỗ trợ lazy evaluation
+ Không có context system
+ Khó test vì phụ thuộc vào controller

== ViewObjectBridge: Flow hoạt động

+ Controller kế thừa từ `ApplicationController`
+ Tự động có `ViewObjectBridge`
+ Override `render` method
+ Trước khi render, gọi `assign_view_object`
+ Tìm view object class theo naming convention
+ Khởi tạo với parameters từ controller
+ Sử dụng `Context` object thay vì controller

== ViewObjectBridge: Code chi tiết

```ruby
# app/controllers/concerns/view_object_bridge.rb
module ViewObjectBridge
  extend ActiveSupport::Concern
  include HasViewObjectContext

  def render(*args, &block)
    assign_view_object(args.dup.extract_options!)  # Tự động gọi
    super(*args, &block)
  end
  def assign_vo_values(values)
    view_object_values.merge!(values)  # Controller truyền data
  end
  def assign_vo_lazy_values(values)
    view_object_lazy_values.merge!(values)  # Lazy evaluation
  end
  # ...
```

```ruby
# app/controllers/concerns/view_object_bridge.rb
def assign_view_object(options = {})
  return if ignore_view_object?
  return if self.class.view_object_ignore_action?(action_name)

  klazz = @vo_class || find_view_object(options)
  return unless klazz

  # Hỗ trợ cả legacy và modern
  return assign_old_view_object(klazz) if klazz < ViewObjectBase

  # Modern: ApplicationViewObject
  @view_object = klazz.new(**view_object_values, **view_object_lazy_values, context: vo_context)
end
```

== ViewObjectBridge: Tìm View Object

```ruby
# app/controllers/concerns/view_object_bridge.rb
def find_view_object(options = {})
  view_object_controller_name = self.class.name.underscore.gsub(/_controller/, '')
  action_name = options[:action] || self.action_name
  view_object_name = "#{action_name}_view_object"
  File.join(ViewObject.config.routes_path, view_object_controller_name, view_object_name).classify.constantize
  # ...
```

== ViewObjectBridge: Ví dụ thực tế

```ruby
# Controller
class CategoryController < ApplicationController
  def show
    @category = Category.find(params[:id])
    @items = @category.items.published

    # Truyền data vào view object
    assign_vo_values(
      category: @category,
      items: @items
    )

    # ViewObjectBridge tự động khởi tạo
    # ViewActions::Category::ShowViewObject
  end
end
```

== ViewObjectBridge: View Object

```ruby
# app/view_objects/view_actions/category/show_view_object.rb
class ViewActions::Category::ShowViewObject < ApplicationViewObject
  # Parameter validation
  required_params :category, :items

  # Nhận context thay vì controller
  def initialize(context:, category:, items:)
    @context = context
    @category = category
    @items = items
  end

  def title
    "#{category.name} の買取価格"
  end

  def items_count
    items.count
  end

  # Truy cập qua context, không phải controller
  def smart_phone?
    context.request_manager.smart_phone?
  end
end
```

== ViewObjectBridge: Lazy Parameters

```ruby
# Controller
class RootController < KaitoriController
  def index
    assign_vo_lazy_values(
      kaitori_history_assessment_achievements: method(:kaitori_history_assessment_achievements)
    )
```

```ruby
# View Object
class ViewActions::Root::IndexViewObject < ApplicationViewObject
  required_lazy_params :kaitori_history_assessment_achievements

  def kaitori_history_item_vo
    Components::Parts::KaitoriHistoryItemViewObject.new(
      assessment_achievements: kaitori_history_assessment_achievements
```

== ViewObjectBridge: Context System

```ruby
# app/controllers/concerns/has_view_object_context.rb
module HasViewObjectContext
  class Context
    attr_reader :params, :meta_manager,
                :request_manager, :url_manager, :view_context

    def initialize(controller)
      @params = controller.params
      @meta_manager = controller.meta_manager
      @request_manager = controller.request_manager
      @url_manager = controller.url_manager
      @view_context = controller.view_context
    end
  end
end
```

#text(fill: green)[Lightweight wrapper - chỉ những gì cần thiết]

#heading(level: 1, numbering: none, outlined: false)[Thank you]

#heading(numbering: none, outlined: false)[Phụ lục]

== Example RSpec on a Decorator

```ruby
require "rails_helper"

describe UserDecorator do
  let(:subject) do
    user.decorate
  end
  let(:user) do
    create(:user, notifications: [
        create(:notification),
        create(:notification)
      ]
    )
  end
  describe "#unread_notifications_text" do
    expect(subject.unread_notifications_text).to include("2 unread notifications")
  end
end
```
