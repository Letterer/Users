@testable import App
import XCTest
import XCTVapor
import Fluent

final class UserRolesConnectActionTests: XCTestCase {

    func testUserShouldBeConnectedToRoleForSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "nickford",
                                   email: "nickford@testemail.com",
                                   name: "Nick Ford")
        let administrator = try Role.get(role: "Administrator")
        try user.$roles.attach(administrator, on: SharedApplication.application().db).wait()
        let role = try Role.create(name: "Consultant", code: "consultant", description: "Consultant")
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "nickford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try User.query(on: SharedApplication.application().db).filter(\.$userName == "nickford").with(\.$roles).first().wait()
        XCTAssert(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
    }

    func testNothingShouldHappendWhenUserTriesToConnectAlreadyConnectedRole() throws {

        // Arrange.
        let user = try User.create(userName: "alanford",
                                   email: "alanford@testemail.com",
                                   name: "Alan Ford")
        let administrator = try Role.get(role: "Administrator")
        try user.$roles.attach(administrator, on: SharedApplication.application().db).wait()
        let role = try Role.create(name: "Policeman", code: "policeman", description: "Policeman")
        try user.$roles.attach(role, on: SharedApplication.application().db).wait()
        
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "alanford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.ok, "Response http status code should be ok (200).")
        let userFromDb = try User.query(on: SharedApplication.application().db).filter(\.$userName == "alanford").with(\.$roles).first().wait()
        XCTAssert(userFromDb!.roles.contains { $0.id == role.id! }, "Role should be attached to the user")
    }

    func testUserShouldNotBeConnectedToRoleIfUserIsNotSuperUser() throws {

        // Arrange.
        let user = try User.create(userName: "wandaford",
                                   email: "wandaford@testemail.com",
                                   name: "Wanda Ford")
        let role = try Role.create(name: "Senior consultant", code: "senior-consultant", description: "Senior consultant")
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: role.id!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "wandaford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.forbidden, "Response http status code should be forbidden (403).")
    }

    func testCorrectStatsCodeShouldBeReturnedIfUserNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "henryford",
                                   email: "henryford@testemail.com",
                                   name: "Henry Ford")
        let administrator = try Role.get(role: "Administrator")
        try user.$roles.attach(administrator, on: SharedApplication.application().db).wait()
        let role = try Role.create(name: "Junior consultant", code: "junior-consultant", description: "Junior consultant")
        let userRoleDto = UserRoleDto(userId: UUID(), roleId: role.id!)

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "henryford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    func testCorrectStatusCodeShouldBeReturnedIfRoleNotExists() throws {

        // Arrange.
        let user = try User.create(userName: "erikford",
                                   email: "erikford@testemail.com",
                                   name: "Erik Ford")
        let administrator = try Role.get(role: "Administrator")
        try user.$roles.attach(administrator, on: SharedApplication.application().db).wait()
        let userRoleDto = UserRoleDto(userId: user.id!, roleId: UUID())

        // Act.
        let response = try SharedApplication.application().sendRequest(
            as: .user(userName: "erikford", password: "p@ssword"),
            to: "/user-roles/connect",
            method: .POST,
            body: userRoleDto
        )

        // Assert.
        XCTAssertEqual(response.status, HTTPResponseStatus.notFound, "Response http status code should be not found (404).")
    }

    static let allTests = [
        ("testUserShouldBeConnectedToRoleForSuperUser", testUserShouldBeConnectedToRoleForSuperUser),
        ("testUserShouldNotBeConnectedToRoleIfUserIsNotSuperUser", testUserShouldNotBeConnectedToRoleIfUserIsNotSuperUser),
        ("testCorrectStatsCodeShouldBeReturnedIfUserNotExists", testCorrectStatsCodeShouldBeReturnedIfUserNotExists),
        ("testCorrectStatusCodeShouldBeReturnedIfRoleNotExists", testCorrectStatusCodeShouldBeReturnedIfRoleNotExists)
    ]
}
