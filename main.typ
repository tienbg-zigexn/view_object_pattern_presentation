#import "@preview/diatypst:0.8.0": *

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

    - Commit cuối từ tháng 3 2019.

    - 1 star trên GitHub (của em).
    #image("assets/view_object_no_star.png")
    https://github.com/kawokas/view_object
  ],
  image("assets/kawakas_avatar.png"),
)

#heading(level: 1, numbering: none, outlined: false)[Thank you]

= Phụ lục

== Decorator Rspec easily

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
