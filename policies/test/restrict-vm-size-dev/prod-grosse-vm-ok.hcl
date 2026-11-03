mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-tfplan-dev-ko.sentinel"
  }
}

mock "tfrun" {
  data = {
    workspace = {
      name = "cloudtech-prod"
    }
  }
}

test {
  rules = {
    main = true
  }
}
