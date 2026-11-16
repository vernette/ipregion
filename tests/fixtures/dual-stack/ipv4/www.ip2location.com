<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8"/>
		<title>What Is My IP Address? - IP2Location.com</title>
	</head>
	<body>
		<p>Your IP address is <span id="ip-address">loading</span></p>
		<script>
	$(function() {
			$(window).scroll(function() {
				if ($(window).scrollTop() + $(window).height() >= $('#ip-address').offset().top) {
					if(!$('#ip-address').attr('loaded')) {
						$('#ip-address').attr('loaded', true);

						$.post('https://api.ip2location.io/query/', {
							ip: '203.0.113.7',
							t: 1700000000,
							token: '0123456789abcdef0123456789abcdef01234567',
						}, function(json) {
							$('#ip-address').html("203.0.113.7");
							$('#isp').html(json.isp);
							$('#country').html(json.countryName);
						});
					}
				}
			});
		});
		</script>
	</body>
</html>
