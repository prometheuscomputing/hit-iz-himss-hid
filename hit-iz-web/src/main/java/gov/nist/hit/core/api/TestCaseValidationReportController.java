/**
 * This software was developed at the National Institute of Standards and Technology by employees of
 * the Federal Government in the course of their official duties. Pursuant to title 17 Section 105
 * of the United States Code this software is not subject to copyright protection and is in the
 * public domain. This is an experimental system. NIST assumes no responsibility whatsoever for its
 * use by other parties, and makes no guarantees, expressed or implied, about its quality,
 * reliability, or any other characteristic. We would appreciate acknowledgement if the software is
 * used. This software can be redistributed and/or modified freely provided that any derivative
 * works bear some notice that they are derived from it, and any modified versions bear some notice
 * that they have been modified.
 */

/*
 * Copy of the hit-core-api 1.1.2-SNAPSHOT class, kept under WEB-INF/classes so it loads
 * ahead of the framework jar. The only change is in the record-clearing paths: the UI
 * clears the previously loaded test case and its last executed test step in parallel,
 * so whichever request commits second finds the report rows already deleted and the
 * flush fails with a stale-state error that surfaces as "An error happened on the
 * server". Nothing is left to delete at that point, so the failure is logged and
 * swallowed. Drop this file once the framework is built with the same fix.
 */
package gov.nist.hit.core.api;

import java.io.InputStream;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.commons.io.IOUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.OptimisticLockingFailureException;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.fasterxml.jackson.annotation.JsonView;

import gov.nist.auth.hit.core.domain.Account;
import gov.nist.auth.hit.core.domain.UserTestCaseReport;
import gov.nist.auth.hit.core.domain.UserTestStepReport;
import gov.nist.auth.hit.core.service.UserTestCaseReportService;
import gov.nist.auth.hit.core.service.UserTestStepReportService;
import gov.nist.hit.core.domain.PersistentReportRequest;
import gov.nist.hit.core.domain.TestCase;
import gov.nist.hit.core.domain.TestResult;
import gov.nist.hit.core.domain.TestStep;
import gov.nist.hit.core.domain.TestStepValidationReport;
import gov.nist.hit.core.domain.UserTestCaseReportRequest;
import gov.nist.hit.core.domain.util.Views;
import gov.nist.hit.core.service.AccountService;
import gov.nist.hit.core.service.Streamer;
import gov.nist.hit.core.service.TestCaseService;
import gov.nist.hit.core.service.TestCaseValidationReportService;
import gov.nist.hit.core.service.TestStepValidationReportService;
import gov.nist.hit.core.service.UserService;
import gov.nist.hit.core.service.exception.MessageValidationException;
import gov.nist.hit.core.service.exception.NoUserFoundException;
import gov.nist.hit.core.service.exception.TestCaseException;
import gov.nist.hit.core.service.exception.UserNotFoundException;
import gov.nist.hit.core.service.exception.ValidationReportException;
import io.swagger.annotations.Api;
import io.swagger.annotations.ApiOperation;
import io.swagger.annotations.ApiParam;

/**
 * @author Harold Affo (NIST)
 * 
 */
@RestController
@RequestMapping("/tcReport")
@Api(value = "Test Case validation report api", tags = "Test Case Validation Report", position = 6)
public class TestCaseValidationReportController {

	static final Logger logger = LoggerFactory.getLogger(TestCaseValidationReportController.class);

	@Autowired
	private TestCaseValidationReportService testCaseValidationReportService;


	@Autowired
	private TestCaseService testCaseService;

	@Autowired
	private AccountService accountService;

	@Autowired
	private Streamer streamer;
	
	
	
	


	
	


	@ApiOperation(value = "Download a test case validation report by the test case's id", nickname = "downloadTestCaseValidationReport", produces = "text/html,application/xml,application/pdf")
	@RequestMapping(value = "/download", method = RequestMethod.POST, consumes = "application/x-www-form-urlencoded; charset=UTF-8")
	public boolean downloadTestCaseValidationReport(
			@ApiParam(value = "the id of the test case", required = true) @RequestParam("testCaseId") final Long testCaseId,
			@ApiParam(value = "the format of the report", required = true) @RequestParam("format") final String format,
			@ApiParam(value = "the name of the test plan", required = false) @RequestParam("testPlan") final String testPlan,
			@ApiParam(value = "the name of the test group", required = false) @RequestParam("testGroup") final String testGroup,
			@ApiParam(value = "the result of the test case", required = true) @RequestParam(value = "result", required = true) String result,
			@ApiParam(value = "the comments of the test case", required = false) @RequestParam(value = "comments", required = false) String comments,

			HttpServletRequest request, HttpServletResponse response) throws ValidationReportException {
		try {
			logger.info("Clearing user records for testcase " + testCaseId);
			Long userId = SessionContext.getCurrentUserId(request.getSession(false));
			if (userId == null || accountService.findOne(userId) == null)
				throw new ValidationReportException("Invalid user credentials");
			TestCase testCase = testCaseService.findOne(testCaseId);
			if (testCase == null)
				throw new TestCaseException(testCaseId);
			String title = testCase.getName().replaceAll(" ", "-");
			InputStream io = null;
			if ("HTML".equalsIgnoreCase(format)) {
				io = IOUtils.toInputStream(testCaseValidationReportService.generateHtml(testCase, userId, result,
						comments, testPlan, testGroup), "UTF-8");
				response.setContentType("text/html");
			} else if ("XML".equalsIgnoreCase(format)) {
				io = IOUtils.toInputStream(testCaseValidationReportService.generateXml(testCase, userId, result,
						comments, testPlan, testGroup), "UTF-8");
				response.setContentType("application/xml");
			} else if ("PDF".equalsIgnoreCase(format)) {
				io = testCaseValidationReportService.generatePdf(testCase, userId, result, comments, testPlan,
						testGroup);
				response.setContentType("application/pdf");
			} else {
				throw new ValidationReportException("Unsupported report format " + format);
			}
			response.setHeader("Content-disposition",
					"attachment;filename=" + title + "-ValidationReport." + format.toLowerCase());
			streamer.stream(response.getOutputStream(), io);

		} catch (Exception e) {
			e.printStackTrace();
			throw new ValidationReportException("Failed to download the reports");
		}
		return true;
	}

	/**
	 * Clear a user records related to a test case
	 * 
	 * @param testCaseId
	 * @param request
	 * @return
	 * @throws MessageValidationException
	 */
	@ApiOperation(value = "", hidden = true)
	@RequestMapping(value = "/{testCaseId}/delete", method = RequestMethod.POST)
	public boolean clearRecords(@PathVariable("testCaseId") final Long testCaseId, HttpServletRequest request)
			throws MessageValidationException {
		logger.info("Clearing user records for testcase " + testCaseId);
		Long userId = SessionContext.getCurrentUserId(request.getSession(false));
		if (userId == null || accountService.findOne(userId) == null)
			throw new ValidationReportException("Invalid user credentials");
		try {
			testCaseValidationReportService.deleteByTestCaseAndUser(userId, testCaseId);
		} catch (OptimisticLockingFailureException e) {
			logger.info("Records for testcase " + testCaseId + " were already cleared by a concurrent request");
		}
		return true;
	}
	
	
	
}
