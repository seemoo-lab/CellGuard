//
//  StudyInformation.swift
//  CellGuard
//
//  Created by jiska on 20.05.24.
//

import SwiftUI

struct LeadingTitleIconTextView: View {

    let icon: String
    let title: String
    let description: String
    let size: CGFloat

    var body: some View {
        VStack(spacing: 0) {

            Text(self.title)
                .font(.title)
                .fontWeight(.bold)
                .padding()
                .multilineTextAlignment(.center)

            Spacer()

            Image(systemName: self.icon)
                .foregroundColor(.blue)
                // We're using a fixed font size as the icons should always be the same size
                // https://sarunw.com/posts/how-to-change-swiftui-font-size/
                .font(Font.custom("SF Pro", fixedSize: self.size))
                .frame(maxWidth: 40, alignment: .center)
                .padding()

            Spacer()

            Text(self.description)
                .multilineTextAlignment(/*@START_MENU_TOKEN@*/.leading/*@END_MENU_TOKEN@*/)
                .foregroundColor(.gray)
                .padding()

            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

}

struct LeadingTitleIconTextView_Preview: PreviewProvider {
    static var previews: some View {
        LeadingTitleIconTextView(icon: "people.3.fill",
                              title: "Our Study",
                              description: "Very long text alsjdfasldfj alsdjfasldf askldfjasldfj alsjdflasdkjfaslkd lasdjfalskd laksdjflasdjfladksfjadslkfj laksdjflasdjfadsl aslkdfjlaskdfj lkjsadflajsdflkasdjflaskdfj lasjdflas asdfasdf asdfasdfas asdfsadf asdfsadf asfasdfasdfsadf asdfasdf",
                              size: 120)
    }
}
