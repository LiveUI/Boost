//
//  TeamsControllerTests.swift
//  ApiCoreTests
//
//  Created by Ondrej Rafaj on 01/03/2018.
//

import Foundation
import XCTest
import ApiCore
import Vapor
import VaporTestTools
import FluentTestTools
import ApiCoreTestTools
import ErrorsCore


class TeamsControllerTests: XCTestCase, TeamsTestCase, UsersTestCase, LinuxTests {
    
    var app: Application!
    
    var team1: Team!
    var team2: Team!
    
    var user1: User!
    var user2: User!
    
    // MARK: Linux
    
    static let allTests: [(String, Any)] = [
        ("testLinuxTests", testLinuxTests),
        ("testGetTeams", testGetTeams),
        ("testCreateTeam", testCreateTeam),
        ("testValidTeamNameCheck", testValidTeamNameCheck),
        ("testInvalidTeamNameCheck", testInvalidTeamNameCheck),
        ("testGetSingleTeam", testGetSingleTeam),
        ("testUpdateSingleTeam", testUpdateSingleTeam),
        ("testPatchSingleTeam", testPatchSingleTeam),
        ("testDeleteSingleTeam", testDeleteSingleTeam),
        ("testLinkUser", testLinkUser),
        ("testTryLinkUserWhereHeIs", testTryLinkUserWhereHeIs),
        ("testLinkUserThatDoesntExist", testLinkUserThatDoesntExist),
        ("testUnlinkUser", testUnlinkUser),
        ("testUnlinkUserThatDoesntExist", testUnlinkUserThatDoesntExist),
        ("testTryUnlinkUserWhereHeIsNot", testTryUnlinkUserWhereHeIsNot)
    ]
    
    func testLinuxTests() {
        doTestLinuxTestsAreOk()
    }
    
    // MARK: Setup
    
    override func setUp() {
        super.setUp()
        
        app = Application.testable.newApiCoreTestApp()
        
        setupTeams()
    }
    
    // MARK: Tests
    
    func testGetTeams() {
        let req = HTTPRequest.testable.get(uri: "/teams")
        let res = app.testable.response(to: req)
        
        res.testable.debug()
        
        XCTAssertTrue(res.testable.has(statusCode: .ok), "Wrong status code")
        XCTAssertTrue(res.testable.has(contentType: "application/json; charset=utf-8"), "Missing content type")
        
        let teams = res.testable.content(as: [Team].self)!
        XCTAssertEqual(teams.count, 2, "There should be two teams in the database")
        XCTAssertTrue(teams.contains(where: { (team) -> Bool in
            return team.id == team1.id && team.id != nil
        }), "Newly created team is not present in the database")
        XCTAssertFalse(teams.contains(where: { (team) -> Bool in
            return team.id == team2.id && team.id != nil
        }), "Team 2 should not be visible")
    }
    
    func testCreateTeam() {
        // Test setup
        var count = app.testable.count(allFor: Team.self)
        XCTAssertEqual(count, 3, "There should be two team entries in the db at the beginning")
        
        // Test current status of the ME user
        let fakeReq = app.testable.fakeRequest()
        let me = try! fakeReq.me().await(on: fakeReq)
        count = try! me.teams.query(on: fakeReq).count().await(on: fakeReq)
        XCTAssertEqual(count, 1, "User should not have any team attached")
        
        // Execute request
        let post = Team(name: "team 3", identifier: "team-3")
        let postData = try! post.asJson()
        let req = HTTPRequest.testable.post(uri: "/teams", data: postData, headers: [
            "Content-Type": "application/json; charset=utf-8"
            ]
        )
        let res = app.testable.response(to: req)
        
        res.testable.debug()
        
        let team = testTeam(res: res, originalTeam: post)
        
        // Test team has been attached to the ME user
        let allUsers = try! team.users.query(on: fakeReq).all().await(on: fakeReq)
        XCTAssertEqual(allUsers.count, 1, "Team should have 1 user attached")
        XCTAssertEqual(allUsers[0].id, me.id, "Team should have ME user attached")
        
        // Test the rest!
        XCTAssertTrue(res.testable.has(statusCode: .created), "Wrong status code")
        
        count = app.testable.count(allFor: Team.self)
        XCTAssertEqual(count, 4, "There should be three team entries in the db")
    }
    
    func testValidTeamNameCheck() {
        let postData = try! Team.Identifier(identifier: "unique-name").asJson()
        let req = HTTPRequest.testable.post(uri: "/teams/check", data: postData, headers: [
            "Content-Type": "application/json; charset=utf-8"
            ]
        )
        let res = app.testable.response(to: req)
        
        res.testable.debug()
        
        let data = res.testable.content(as: SuccessResponse.self)!
        XCTAssertEqual(data.code, "ok")
        XCTAssertEqual(data.description, "Identifier available")
        
        XCTAssertTrue(res.testable.has(statusCode: .ok), "Wrong status code")
        XCTAssertTrue(res.testable.has(contentType: "application/json; charset=utf-8"), "Missing content type")
    }
    
    func testInvalidTeamNameCheck() {
        let postData = try! Team.Identifier(identifier: "team-1").asJson()
        let req = HTTPRequest.testable.post(uri: "/teams/check", data: postData, headers: [
            "Content-Type": "application/json; charset=utf-8"
            ]
        )
        let res = app.testable.response(to: req)
        
        res.testable.debug()
        
        let data = res.testable.content(as: ErrorResponse.self)!
        XCTAssertEqual(data.error, "app_error")
        XCTAssertEqual(data.description, "Identifier already exists")
        
        XCTAssertTrue(res.testable.has(statusCode: .conflict), "Wrong status code")
        XCTAssertTrue(res.testable.has(contentType: "application/json; charset=utf-8"), "Missing content type")
    }
    
    func testLinkUser() {
        XCTFail()
    }
    
    func testTryLinkUserWhereHeIs() {
        XCTFail()
    }
    
    func testLinkUserThatDoesntExist() {
        XCTFail()
    }
    
    func testUnlinkUser() {
        XCTFail()
    }
    
    func testUnlinkUserThatDoesntExist() {
        // Should be same as testLinkUserThatDoesntExist
        XCTFail()
    }
    
    func testTryUnlinkUserWhereHeIsNot() {
        XCTFail()
    }
    
    func testGetSingleTeam() {
        let req = HTTPRequest.testable.get(uri: URI(rawValue: "/teams/\(team1.id!.uuidString)")!)
        let res = app.testable.response(to: req)
        
        res.testable.debug()
        
        testTeam(res: res)
        
        XCTAssertTrue(res.testable.has(statusCode: .ok), "Wrong status code")
    }
    
    func testUpdateSingleTeam() {
        let testName = "Stay PUT"
        team1.name = testName
        team1.identifier = team1.name.safeText
        
        let postData = try! team1.asJson()
        let req = HTTPRequest.testable.put(uri: URI(rawValue: "/teams/\(team1.id!.uuidString)")!, data: postData, headers: [
            "Content-Type": "application/json; charset=utf-8"
            ]
        )
        let res = app.testable.response(to: req)
        
        res.testable.debug()
        
        let data = testTeam(res: res)
        XCTAssertEqual(data.name, testName, "Name of the team doesn't match")
        XCTAssertEqual(data.identifier, testName.safeText, "Identifier of the team doesn't match")
        
        XCTAssertTrue(res.testable.has(statusCode: .ok), "Wrong status code")
    }
    
    // PATCH
    func testPatchSingleTeam() {
        let testName = "team 1"
        let postData = try! team1.asJson()
        let req = HTTPRequest.testable.patch(uri: URI(rawValue: "/teams/\(team1.id!.uuidString)")!, data: postData, headers: [
            "Content-Type": "application/json; charset=utf-8"
            ]
        )
        let res = app.testable.response(to: req)
        
        res.testable.debug()
        
        let data = testTeam(res: res)
        XCTAssertEqual(data.name, testName, "Name of the team doesn't match")
        XCTAssertEqual(data.identifier, testName.safeText, "Identifier of the team doesn't match")
        
        XCTAssertTrue(res.testable.has(statusCode: .ok), "Wrong status code")
    }
    
    func testDeleteSingleTeam() {
        let count = app.testable.count(allFor: Team.self)
        XCTAssertEqual(count, 3)
        
        let req = HTTPRequest.testable.delete(uri: URI(rawValue: "/teams/\(team2.id!.uuidString)")!)
        let res = app.testable.response(to: req)
        
        res.testable.debug()
        
        XCTAssertTrue(res.testable.has(statusCode: .noContent), "Wrong status code")
        
        let all = app.testable.all(for: Team.self)
        XCTAssertEqual(all.count, 2)
        XCTAssertTrue(all.contains(where: { (team) -> Bool in
            team.id == team1.id
        }), "Team 1 should not have been deleted")
    }
    
}

extension TeamsControllerTests {
    
    @discardableResult private func testTeam(res: Response, originalTeam: Team? = nil) -> Team {
        let data = res.testable.content(as: Team.self)
        XCTAssertNotNil(data, "Team can't be nil")
        
        XCTAssertTrue(res.testable.has(contentType: "application/json; charset=utf-8"), "Missing content type")
        
        if let data = data {
            if let originalTeam = originalTeam {
                XCTAssertEqual(data.identifier, originalTeam.identifier, "Identifier of the team doesn't match")
            }
            else {
                XCTAssertEqual(data.id, team1.id, "Id of the team doesn't match")
            }
            let dbData = app.testable.one(for: Team.self, id: data.id!)
            XCTAssertNotNil(dbData, "Team should have been found in the DB")
            
            return dbData!
        }
        
        fatalError("This should not happen Yo!")
    }
    
}
