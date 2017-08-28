package k8s_lbs_test

import (
	"fmt"
	"net/http"
	"time"

	"os"
	"os/exec"
	"strings"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
	"github.com/onsi/gomega/gexec"
)

var _ = Describe("Deploy workload", func() {

	var loadbalancerAddress string

	It("exposes routes via LBs", func() {
		deployNginx := runner.RunKubectlCommand("create", "-f", nginxLBSpec)
		Eventually(deployNginx, "60s").Should(gexec.Exit(0))
		rolloutWatch := runner.RunKubectlCommand("rollout", "status", "deployment/nginx", "-w")
		Eventually(rolloutWatch, "120s").Should(gexec.Exit(0))
		loadbalancerAddress = ""
		Eventually(func() string {
			output := []string{}
			if iaas == "gcp" {
				output = runner.GetOutput("get", "service", "nginx", "-o", "jsonpath={.status.loadBalancer.ingress[0].ip}")
			} else {
				output = runner.GetOutput("get", "service", "nginx", "-o", "jsonpath={.status.loadBalancer.ingress[0].hostname}")
			}
			fmt.Printf("Output [%s]", output)
			if len(output) != 0 {
				loadbalancerAddress = output[0]
			}
			return loadbalancerAddress
		}, "120s", "5s").Should(Not(Equal("")))

		appUrl := fmt.Sprintf("http://%s", loadbalancerAddress)

		timeout := time.Duration(5 * time.Second)
		httpClient := http.Client{
			Timeout: timeout,
		}

		Eventually(func() int {
			result, err := httpClient.Get(appUrl)
			if err != nil {
				fmt.Fprintf(GinkgoWriter, "Failed to get response from %s: %v", appUrl, err)
				return -1
			}
			if result.StatusCode != 200 {
				fmt.Fprintf(GinkgoWriter, "Failed to get response from %s: StatusCode %v", appUrl, result.StatusCode)
			}
			return result.StatusCode
		}, "300s", "5s").Should(Equal(200))
	})

	AfterEach(func() {

		lbSecurityGroup := ""

		if iaas == "aws" {
			// Get the LB
			if loadbalancerAddress != "" {
				// Get the security group
				cmd := exec.Command("aws", "elb", "describe-load-balancers", "--query",
					fmt.Sprintf("'LoadBalancerDescriptions[?DNSName==`%s`].[SecurityGroups]'", loadbalancerAddress),
					"--output text")
				fmt.Printf("Get LoadBalancer security group - %s", cmd.Args)
				session, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)

				Expect(err).NotTo(HaveOccurred())
				output := strings.Fields(string(session.Out.Contents()))
				if len(output) != 0 {
					lbSecurityGroup = output[0]
					fmt.Printf("Found LB security group [%s]", lbSecurityGroup)
				}

			}
		}

		session := runner.RunKubectlCommand("delete", "-f", nginxLBSpec)
		session.Wait("60s")

		// Teardown the security group
		if lbSecurityGroup != "" {
			cmd := exec.Command("aws", "ec2", "revoke-security-group-ingress", "--group-id",
				os.Getenv("AWS_INGRESS_GROUP_ID"), "--source-group", lbSecurityGroup, "--protocol", "all")
			fmt.Printf("Teardown security groups - %s", cmd.Args)
			_, err := gexec.Start(cmd, GinkgoWriter, GinkgoWriter)
			Expect(err).NotTo(HaveOccurred())
		}

	})

})
